import CoreData
import Foundation

// MARK: - Platform

@objc(Platform)
public class Platform: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var currency: String?
    @NSManaged public var currentBalance: Double
    @NSManaged public var createdAt: Date?
    @NSManaged public var deposits: NSSet?
    @NSManaged public var withdrawals: NSSet?
    @NSManaged public var onlineSessions: NSSet?
    @NSManaged public var adjustments: NSSet?

    public static func fetchRequest() -> NSFetchRequest<Platform> {
        NSFetchRequest<Platform>(entityName: "Platform")
    }
}

extension Platform {
    @objc(addDepositsObject:)
    @NSManaged public func addToDeposits(_ value: Deposit)
    @objc(removeDepositsObject:)
    @NSManaged public func removeFromDeposits(_ value: Deposit)
    @objc(addDeposits:)
    @NSManaged public func addToDeposits(_ values: NSSet)

    @objc(addWithdrawalsObject:)
    @NSManaged public func addToWithdrawals(_ value: Withdrawal)
    @objc(removeWithdrawalsObject:)
    @NSManaged public func removeFromWithdrawals(_ value: Withdrawal)
    @objc(addWithdrawals:)
    @NSManaged public func addToWithdrawals(_ values: NSSet)

    @objc(addOnlineSessionsObject:)
    @NSManaged public func addToOnlineSessions(_ value: OnlineCash)
    @objc(removeOnlineSessionsObject:)
    @NSManaged public func removeFromOnlineSessions(_ value: OnlineCash)
    @objc(addOnlineSessions:)
    @NSManaged public func addToOnlineSessions(_ values: NSSet)

    @objc(addAdjustmentsObject:)
    @NSManaged public func addToAdjustments(_ value: Adjustment)
    @objc(removeAdjustmentsObject:)
    @NSManaged public func removeFromAdjustments(_ value: Adjustment)
    @objc(addAdjustments:)
    @NSManaged public func addToAdjustments(_ values: NSSet)
}

extension Platform: Identifiable {}

// MARK: - OnlineCash

@objc(OnlineCash)
public class OnlineCash: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var startTime: Date?
    @NSManaged public var endTime: Date?
    @NSManaged public var duration: Double
    @NSManaged public var gameType: String?
    @NSManaged public var blinds: String?
    @NSManaged public var tableSize: Int16
    @NSManaged public var tables: Int16
    @NSManaged public var balanceBefore: Double
    @NSManaged public var balanceAfter: Double
    @NSManaged public var netProfitLoss: Double
    @NSManaged public var netProfitLossBase: Double
    @NSManaged public var exchangeRateToBase: Double
    @NSManaged public var handsCount: Int32
    @NSManaged public var notes: String?
    @NSManaged public var platform: Platform?

    public static func fetchRequest() -> NSFetchRequest<OnlineCash> {
        NSFetchRequest<OnlineCash>(entityName: "OnlineCash")
    }
}

extension OnlineCash: Identifiable {}

// MARK: - LiveCash

@objc(LiveCash)
public class LiveCash: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var startTime: Date?
    @NSManaged public var endTime: Date?
    @NSManaged public var duration: Double
    @NSManaged public var gameType: String?
    @NSManaged public var blinds: String?
    @NSManaged public var tableSize: Int16
    @NSManaged public var location: String?
    @NSManaged public var currency: String?
    @NSManaged public var exchangeRateToBase: Double
    @NSManaged public var buyIn: Double
    @NSManaged public var cashOut: Double
    @NSManaged public var tips: Double
    @NSManaged public var netProfitLoss: Double
    @NSManaged public var netProfitLossBase: Double
    @NSManaged public var handsCount: Int32
    @NSManaged public var notes: String?

    public static func fetchRequest() -> NSFetchRequest<LiveCash> {
        NSFetchRequest<LiveCash>(entityName: "LiveCash")
    }
}

extension LiveCash: Identifiable {}

// MARK: - Deposit

@objc(Deposit)
public class Deposit: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var date: Date?
    @NSManaged public var amountSent: Double
    @NSManaged public var amountReceived: Double
    @NSManaged public var isForeignExchange: Bool
    @NSManaged public var effectiveExchangeRate: Double
    @NSManaged public var processingFee: Double
    @NSManaged public var method: String?
    @NSManaged public var platform: Platform?

    public static func fetchRequest() -> NSFetchRequest<Deposit> {
        NSFetchRequest<Deposit>(entityName: "Deposit")
    }
}

extension Deposit: Identifiable {}

// MARK: - Withdrawal

@objc(Withdrawal)
public class Withdrawal: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var date: Date?
    @NSManaged public var amountRequested: Double
    @NSManaged public var amountReceived: Double
    @NSManaged public var isForeignExchange: Bool
    @NSManaged public var effectiveExchangeRate: Double
    @NSManaged public var processingFee: Double
    @NSManaged public var method: String?
    @NSManaged public var platform: Platform?

    public static func fetchRequest() -> NSFetchRequest<Withdrawal> {
        NSFetchRequest<Withdrawal>(entityName: "Withdrawal")
    }
}

extension Withdrawal: Identifiable {}

// MARK: - Adjustment

@objc(Adjustment)
public class Adjustment: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var amount: Double
    @NSManaged public var date: Date?
    @NSManaged public var currency: String?
    @NSManaged public var exchangeRateToBase: Double
    @NSManaged public var amountBase: Double
    @NSManaged public var isOnline: Bool
    @NSManaged public var location: String?
    @NSManaged public var notes: String?
    @NSManaged public var platform: Platform?

    public static func fetchRequest() -> NSFetchRequest<Adjustment> {
        NSFetchRequest<Adjustment>(entityName: "Adjustment")
    }
}

extension Adjustment: Identifiable {}
