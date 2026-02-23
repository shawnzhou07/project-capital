import Foundation
import CoreData

// MARK: - Platform Business Logic

extension Platform {
    var depositsArray: [Deposit] {
        (deposits?.allObjects as? [Deposit] ?? []).sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
    }

    var withdrawalsArray: [Withdrawal] {
        (withdrawals?.allObjects as? [Withdrawal] ?? []).sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
    }

    var onlineSessionsArray: [OnlineCash] {
        (onlineSessions?.allObjects as? [OnlineCash] ?? []).sorted { ($0.startTime ?? .distantPast) > ($1.startTime ?? .distantPast) }
    }

    var adjustmentsArray: [Adjustment] {
        (adjustments?.allObjects as? [Adjustment] ?? []).sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }

    // Latest conversion rate: platform currency → base currency (e.g. CAD per USD).
    // From FX deposit: effectiveExchangeRate = platformCurrency/baseCurrency → invert to get baseCurrency/platformCurrency.
    // From FX withdrawal: effectiveExchangeRate = baseCurrency/platformCurrency → use directly.
    var latestFXConversionRate: Double {
        var transactions: [(date: Date, rateToBase: Double)] = []

        for d in depositsArray where d.isForeignExchange && d.effectiveExchangeRate > 0 {
            transactions.append((date: d.date ?? .distantPast, rateToBase: 1.0 / d.effectiveExchangeRate))
        }

        for w in withdrawalsArray where w.isForeignExchange && w.effectiveExchangeRate > 0 {
            transactions.append((date: w.date ?? .distantPast, rateToBase: w.effectiveExchangeRate))
        }

        return transactions.sorted { $0.date < $1.date }.last?.rateToBase ?? 1.0
    }

    // Total deposited in base currency
    var totalDeposited: Double {
        let rate = latestFXConversionRate
        return depositsArray.reduce(0) { sum, d in
            if d.isForeignExchange {
                return sum + d.amountSent          // Already in base currency
            } else {
                return sum + d.amountSent * rate   // Convert platform → base
            }
        }
    }

    // Total withdrawn in base currency
    var totalWithdrawn: Double {
        let rate = latestFXConversionRate
        return withdrawalsArray.reduce(0) { sum, w in
            if w.isForeignExchange {
                return sum + w.amountReceived          // Already in base currency
            } else {
                return sum + w.amountReceived * rate   // Convert platform → base
            }
        }
    }

    // Net result: withdrawals (base) + current balance (base) − deposits (base).
    // Returns 0 if no deposits or withdrawals have been recorded yet.
    var netResult: Double {
        guard !depositsArray.isEmpty || !withdrawalsArray.isEmpty else { return 0 }
        let rate = latestFXConversionRate
        let currentValueBase = currentBalance * rate
        return totalWithdrawn + currentValueBase - totalDeposited
    }

    // Net result expressed in the platform's own currency (for supplemental display)
    var netResultInPlatformCurrency: Double {
        let rate = latestFXConversionRate
        guard rate > 0 else { return netResult }
        return netResult / rate
    }

    var displayName: String { name ?? "Unknown Platform" }
    var displayCurrency: String { currency ?? "USD" }
}

// MARK: - Session Computed Properties

extension OnlineCash {
    var computedDuration: Double {
        guard let start = startTime, let end = endTime else { return duration }
        return end.timeIntervalSince(start) / 3600.0
    }

    var isLive: Bool { false }

    var effectiveHands: Int {
        if handsCount > 0 { return Int(handsCount) }
        let settings = UserSettings.shared
        let hrs = computedDuration
        let tablesCount = max(1, Int(tables))
        return Int(hrs * Double(settings.handsPerHourOnline) * Double(tablesCount))
    }

    var sessionDate: Date { startTime ?? Date() }
    var platformName: String { platform?.displayName ?? "Unknown" }
    var platformCurrency: String { platform?.displayCurrency ?? "USD" }
    var displayGameType: String { gameType ?? "Hold'em" }
    var displayBlinds: String { blinds ?? "" }

    var isActive: Bool {
        endTime == nil && startTime != nil
    }
}

extension LiveCash {
    var computedDuration: Double {
        guard let start = startTime, let end = endTime else { return duration }
        return end.timeIntervalSince(start) / 3600.0
    }

    var isLive: Bool { true }

    var effectiveHands: Int {
        if handsCount > 0 { return Int(handsCount) }
        let settings = UserSettings.shared
        return Int(computedDuration * Double(settings.handsPerHourLive))
    }

    var sessionDate: Date { startTime ?? Date() }
    var displayLocation: String { location ?? "Unknown Location" }
    var displayCurrency: String { currency ?? "USD" }
    var displayGameType: String { gameType ?? "Hold'em" }
    var displayBlinds: String { blinds ?? "" }

    var isActive: Bool {
        endTime == nil && startTime != nil
    }

    // Net result excludes tips — tips are for record-keeping only
    var netResult: Double { cashOut - buyIn }
    // Use exchangeRateCashOut when set (new dual-rate system), fall back to exchangeRateToBase
    var netResultBase: Double {
        let rate = exchangeRateCashOut > 0 ? exchangeRateCashOut : exchangeRateToBase
        return netResult * rate
    }
    var hasExchangeRates: Bool { currency != nil && currency != "" }
}

// MARK: - Stats Computation

struct StatsResult {
    var netResult: Double = 0
    var netResultNoAdj: Double = 0
    var totalHours: Double = 0
    var totalHands: Int = 0
    var sessionCount: Int = 0
    var winCount: Int = 0
    var adjustmentsTotal: Double = 0

    var hourlyRate: Double {
        totalHours > 0 ? netResult / totalHours : 0
    }

    var avgResult: Double {
        sessionCount > 0 ? netResult / Double(sessionCount) : 0
    }

    var winRate: Double {
        sessionCount > 0 ? Double(winCount) / Double(sessionCount) : 0
    }
}

enum SessionFilter {
    case all, live, online
    case platform(Platform)
    case gameType(String)
    case location(String)
}

enum DateFilter {
    case allTime
    case thisMonth
    case thisYear
    case custom(Date, Date)

    func isIncluded(_ date: Date) -> Bool {
        let cal = Calendar.current
        let now = Date()
        switch self {
        case .allTime: return true
        case .thisMonth:
            return cal.isDate(date, equalTo: now, toGranularity: .month)
        case .thisYear:
            return cal.isDate(date, equalTo: now, toGranularity: .year)
        case .custom(let start, let end):
            return date >= start && date <= end
        }
    }
}

func computeStats(
    online: [OnlineCash],
    live: [LiveCash],
    adjustments: [Adjustment],
    dateFilter: DateFilter,
    sessionFilter: SessionFilter,
    showAdjustments: Bool
) -> StatsResult {
    var result = StatsResult()

    var filteredOnline = online.filter { dateFilter.isIncluded($0.sessionDate) }
    var filteredLive = live.filter { dateFilter.isIncluded($0.sessionDate) }

    switch sessionFilter {
    case .all: break
    case .live: filteredOnline = []
    case .online: filteredLive = []
    case .platform(let p):
        filteredOnline = filteredOnline.filter { $0.platform == p }
        filteredLive = []
    case .gameType(let gt):
        filteredOnline = filteredOnline.filter { $0.gameType == gt }
        filteredLive = filteredLive.filter { $0.gameType == gt }
    case .location(let loc):
        filteredLive = filteredLive.filter { $0.location == loc }
        filteredOnline = []
    }

    for session in filteredOnline {
        result.netResultNoAdj += session.netProfitLossBase
        result.totalHours += session.computedDuration
        result.totalHands += session.effectiveHands
        result.sessionCount += 1
        if session.netProfitLoss > 0 { result.winCount += 1 }
    }

    for session in filteredLive {
        // Use tips-excluded net result for accuracy
        result.netResultNoAdj += session.netResultBase
        result.totalHours += session.computedDuration
        result.totalHands += session.effectiveHands
        result.sessionCount += 1
        if session.netResult > 0 { result.winCount += 1 }
    }

    if showAdjustments {
        let filteredAdj = adjustments.filter { dateFilter.isIncluded($0.date ?? .distantPast) }
        result.adjustmentsTotal = filteredAdj.reduce(0) { $0 + $1.amountBase }
        switch sessionFilter {
        case .all, .live, .online: break
        case .platform(let p):
            result.adjustmentsTotal = filteredAdj.filter { $0.platform == p }.reduce(0) { $0 + $1.amountBase }
        default: break
        }
    }

    result.netResult = result.netResultNoAdj + result.adjustmentsTotal
    return result
}
