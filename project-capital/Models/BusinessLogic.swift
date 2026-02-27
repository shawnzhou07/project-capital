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

    var totalDeposited: Double {
        let rate = latestFXConversionRate
        return depositsArray.reduce(0) { sum, d in
            d.isForeignExchange ? sum + d.amountSent : sum + d.amountSent * rate
        }
    }

    var totalWithdrawn: Double {
        let rate = latestFXConversionRate
        return withdrawalsArray.reduce(0) { sum, w in
            w.isForeignExchange ? sum + w.amountReceived : sum + w.amountReceived * rate
        }
    }

    var totalAdjustments: Double {
        adjustmentsArray.reduce(0) { $0 + $1.amountBase }
    }

    // Net result: withdrawals (base) + current balance (base) − deposits (base) + adjustments (base).
    var netResult: Double {
        guard !depositsArray.isEmpty || !withdrawalsArray.isEmpty else { return 0 }
        let rate = latestFXConversionRate
        let currentValueBase = currentBalance * rate
        return totalWithdrawn + currentValueBase - totalDeposited + totalAdjustments
    }

    // Net result in platform currency — fully independent formula using platform-native amounts.
    // deposit.amountReceived and withdrawal.amountRequested are always in platform currency.
    var netResultInPlatformCurrency: Double {
        guard !depositsArray.isEmpty || !withdrawalsArray.isEmpty else { return 0 }
        let totalDepPlatform = depositsArray.reduce(0) { $0 + $1.amountReceived }
        let totalWdPlatform = withdrawalsArray.reduce(0) { $0 + $1.amountRequested }
        // Convert adjustments (stored in base) back to platform currency using latest rate
        let rate = latestFXConversionRate
        let adjPlatform = rate > 0 ? totalAdjustments / rate : 0
        return totalWdPlatform + currentBalance - totalDepPlatform + adjPlatform
    }

    var displayName: String { name ?? "Unknown Platform" }
    var displayCurrency: String { currency ?? "USD" }
}

// MARK: - Session Computed Properties

extension OnlineCash {
    var computedDuration: Double {
        guard let start = startTime, let end = endTime else { return duration }
        let rawHours = end.timeIntervalSince(start) / 3600.0
        let breakHours = breakTime / 60.0
        return max(0, rawHours - breakHours)
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

    var displayBlinds: String {
        guard smallBlind > 0 && bigBlind > 0 else { return "" }
        let base = "\(AppFormatter.blindValue(smallBlind))/\(AppFormatter.blindValue(bigBlind))"
        if straddle > 0 && ante > 0 {
            return "\(base)/\(AppFormatter.blindValue(straddle)) (\(AppFormatter.blindValue(ante)))"
        } else if straddle > 0 {
            return "\(base)/\(AppFormatter.blindValue(straddle))"
        } else if ante > 0 {
            return "\(base) (\(AppFormatter.blindValue(ante)))"
        } else {
            return base
        }
    }

    var isActive: Bool { endTime == nil && startTime != nil }

    var bbWon: Double {
        guard bigBlind > 0 else { return 0 }
        return netProfitLoss / bigBlind
    }

    var bbPer100: Double {
        let hands = effectiveHands
        guard hands > 0, bigBlind > 0 else { return 0 }
        return (bbWon / Double(hands)) * 100.0
    }
}

extension LiveCash {
    var computedDuration: Double {
        guard let start = startTime, let end = endTime else { return duration }
        let rawHours = end.timeIntervalSince(start) / 3600.0
        let breakHours = breakTime / 60.0
        return max(0, rawHours - breakHours)
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

    var displayBlinds: String {
        guard smallBlind > 0 && bigBlind > 0 else { return "" }
        let base = "\(AppFormatter.blindValue(smallBlind))/\(AppFormatter.blindValue(bigBlind))"
        if straddle > 0 && ante > 0 {
            return "\(base)/\(AppFormatter.blindValue(straddle)) (\(AppFormatter.blindValue(ante)))"
        } else if straddle > 0 {
            return "\(base)/\(AppFormatter.blindValue(straddle))"
        } else if ante > 0 {
            return "\(base) (\(AppFormatter.blindValue(ante)))"
        } else {
            return base
        }
    }

    var isActive: Bool { endTime == nil && startTime != nil }

    // Net result excludes tips
    var netResult: Double { cashOut - buyIn }

    var netResultBase: Double {
        if exchangeRateCashOut > 0 && exchangeRateBuyIn > 0 {
            return (cashOut * exchangeRateCashOut) - (buyIn * exchangeRateBuyIn)
        }
        let rate = exchangeRateToBase > 0 ? exchangeRateToBase : 1.0
        return netResult * rate
    }

    var hasExchangeRates: Bool { currency != nil && currency != "" }

    var bbWon: Double {
        guard bigBlind > 0 else { return 0 }
        return netResult / bigBlind
    }

    var bbPer100: Double {
        let hands = effectiveHands
        guard hands > 0, bigBlind > 0 else { return 0 }
        return (bbWon / Double(hands)) * 100.0
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
    var loseCount: Int = 0
    var adjustmentsTotal: Double = 0
    var totalBBWon: Double = 0
    var totalBuyIn: Double = 0
    var totalTips: Double = 0
    var biggestWin: Double = 0
    var biggestLoss: Double = 0
    var longestSessionHours: Double = 0
    var longestWinStreak: Int = 0
    var longestLoseStreak: Int = 0

    var hourlyRate: Double {
        totalHours > 0 ? netResult / totalHours : 0
    }

    var avgResult: Double {
        sessionCount > 0 ? netResult / Double(sessionCount) : 0
    }

    var avgSessionDuration: Double {
        sessionCount > 0 ? totalHours / Double(sessionCount) : 0
    }

    var avgBuyIn: Double {
        sessionCount > 0 ? totalBuyIn / Double(sessionCount) : 0
    }

    var winRate: Double {
        sessionCount > 0 ? Double(winCount) / Double(sessionCount) : 0
    }

    var bbPerHour: Double {
        totalHours > 0 ? totalBBWon / totalHours : 0
    }

    var bbPer100: Double {
        totalHands > 0 ? (totalBBWon / Double(totalHands)) * 100.0 : 0
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
        let netBase = session.netProfitLossBase
        result.netResultNoAdj += netBase
        result.totalHours += session.computedDuration
        result.totalHands += session.effectiveHands
        result.sessionCount += 1
        if session.netProfitLoss > 0 { result.winCount += 1 } else { result.loseCount += 1 }
        result.totalBBWon += session.bbWon
        let rate = session.exchangeRateToBase > 0 ? session.exchangeRateToBase : 1.0
        result.totalBuyIn += session.balanceBefore * rate
        if netBase > result.biggestWin { result.biggestWin = netBase }
        if netBase < result.biggestLoss { result.biggestLoss = netBase }
        if session.computedDuration > result.longestSessionHours { result.longestSessionHours = session.computedDuration }
    }

    for session in filteredLive {
        let netBase = session.netResultBase
        result.netResultNoAdj += netBase
        result.totalHours += session.computedDuration
        result.totalHands += session.effectiveHands
        result.sessionCount += 1
        if session.netResult > 0 { result.winCount += 1 } else { result.loseCount += 1 }
        result.totalBBWon += session.bbWon
        let buyInBase: Double = session.exchangeRateBuyIn > 0
            ? session.buyIn * session.exchangeRateBuyIn
            : session.buyIn * (session.exchangeRateToBase > 0 ? session.exchangeRateToBase : 1.0)
        result.totalBuyIn += buyInBase
        let tipsRate: Double = session.exchangeRateCashOut > 0
            ? session.exchangeRateCashOut
            : (session.exchangeRateToBase > 0 ? session.exchangeRateToBase : 1.0)
        result.totalTips += session.tips * tipsRate
        if netBase > result.biggestWin { result.biggestWin = netBase }
        if netBase < result.biggestLoss { result.biggestLoss = netBase }
        if session.computedDuration > result.longestSessionHours { result.longestSessionHours = session.computedDuration }
    }

    // Win/lose streaks from all sessions sorted chronologically
    struct SR { let date: Date; let isWin: Bool }
    var combined: [SR] = []
    for s in filteredOnline { combined.append(SR(date: s.sessionDate, isWin: s.netProfitLoss > 0)) }
    for s in filteredLive   { combined.append(SR(date: s.sessionDate, isWin: s.netResult > 0)) }
    combined.sort { $0.date < $1.date }
    var curWin = 0, curLose = 0
    for sr in combined {
        if sr.isWin {
            curWin += 1; curLose = 0
            if curWin > result.longestWinStreak { result.longestWinStreak = curWin }
        } else {
            curLose += 1; curWin = 0
            if curLose > result.longestLoseStreak { result.longestLoseStreak = curLose }
        }
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
