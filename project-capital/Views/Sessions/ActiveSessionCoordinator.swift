import Foundation
import Combine
import SwiftUI
import CoreData

class ActiveSessionCoordinator: ObservableObject {

    enum GameCategory {
        case cashGame
    }

    @Published var isFormPresented = false
    @Published var pendingGameCategory: GameCategory? = nil

    // Cross-tab navigation
    @Published var selectedTab: Int = 0
    @Published var shouldOpenAddPlatform: Bool = false
    @Published var platformIDForDeposit: NSManagedObjectID? = nil
    @Published var platformIDForWithdrawal: NSManagedObjectID? = nil
    @Published var adjustmentPlatformID: NSManagedObjectID? = nil

    func openCashGame() {
        pendingGameCategory = .cashGame
        isFormPresented = true
    }

    func openActiveSession() {
        isFormPresented = true
    }

    func dismissForm() {
        isFormPresented = false
        pendingGameCategory = nil
    }
}
