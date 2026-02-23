import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let ctx = result.container.viewContext

        // Sample platform
        let platform = Platform(context: ctx)
        platform.id = UUID()
        platform.name = "PokerStars Ontario"
        platform.currency = "CAD"
        platform.currentBalance = 500.0
        platform.createdAt = Date()

        // Sample online session
        let online = OnlineCash(context: ctx)
        online.id = UUID()
        online.platform = platform
        online.startTime = Calendar.current.date(byAdding: .hour, value: -3, to: Date())
        online.endTime = Date()
        online.duration = 3.0
        online.gameType = "No Limit Hold'em"
        online.blinds = "$0.25/$0.50"
        online.tableSize = 6
        online.tables = 2
        online.balanceBefore = 500.0
        online.balanceAfter = 562.50
        online.netProfitLoss = 62.50
        online.exchangeRateToBase = 1.0
        online.netProfitLossBase = 62.50

        // Sample live session
        let live = LiveCash(context: ctx)
        live.id = UUID()
        live.startTime = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        live.endTime = Calendar.current.date(byAdding: .hour, value: -20, to: Date())
        live.duration = 4.0
        live.gameType = "No Limit Hold'em"
        live.blinds = "$1/$2"
        live.tableSize = 9
        live.location = "Casino Niagara"
        live.currency = "CAD"
        live.exchangeRateToBase = 1.0
        live.buyIn = 300.0
        live.cashOut = 480.0
        live.tips = 20.0
        live.netProfitLoss = 160.0
        live.netProfitLossBase = 160.0

        do {
            try ctx.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "DataModel")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func save() {
        let ctx = container.viewContext
        if ctx.hasChanges {
            do {
                try ctx.save()
            } catch {
                let nsError = error as NSError
                print("Core Data save error: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}
