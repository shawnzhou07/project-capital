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

    // Total deposited in base currency
    var totalDeposited: Double {
        depositsArray.reduce(0) { $0 + $1.amountSent }
    }

    // Total withdrawn in base currency
    var totalWithdrawn: Double {
        withdrawalsArray.reduce(0) { $0 + $1.amountReceived }
    }

    // Net result: what you got out + current value - what you put in
    // Uses the most recent withdrawal rate for current balance valuation if available
    var netResult: Double {
        let averageRate = averageDepositRate
        let currentValueInBase = currentBalance * (latestWithdrawalRate ?? averageRate)
        return totalWithdrawn + currentValueInBase - totalDeposited
    }

    var latestWithdrawalRate: Double? {
        guard let latest = withdrawalsArray.last,
              latest.amountRequested > 0 else { return nil }
        return latest.amountReceived / latest.amountRequested
    }

    var averageDepositRate: Double {
        let fx = depositsArray.filter { $0.isForeignExchange }
        guard !fx.isEmpty else { return 1.0 }
        let totalSent = fx.reduce(0.0) { $0 + $1.amountSent }
        let totalReceived = fx.reduce(0.0) { $0 + $1.amountReceived }
        guard totalSent > 0 else { return 1.0 }
        return totalReceived / totalSent
    }

    // FIFO cost basis parcels for the platform currency
    // Returns list of (amount in platform currency, cost basis in base currency)
    var costBasisParcels: [(amount: Double, costPerUnit: Double)] {
        var parcels: [(amount: Double, costPerUnit: Double)] = []
        for deposit in depositsArray {
            let rate: Double
            if deposit.isForeignExchange && deposit.effectiveExchangeRate > 0 {
                rate = deposit.effectiveExchangeRate
            } else if deposit.amountReceived > 0 {
                rate = deposit.amountSent / deposit.amountReceived
            } else {
                rate = 1.0
            }
            parcels.append((amount: deposit.amountReceived, costPerUnit: rate))
        }
        return parcels
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
        result.netResultNoAdj += session.netProfitLossBase
        result.totalHours += session.computedDuration
        result.totalHands += session.effectiveHands
        result.sessionCount += 1
        if session.netProfitLoss > 0 { result.winCount += 1 }
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
