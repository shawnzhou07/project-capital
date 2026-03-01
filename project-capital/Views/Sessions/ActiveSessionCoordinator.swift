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

    // Unified active session navigation: both the floating bar tap and the
    // session row tap route through these bindings into SessionsListView's
    // navigationDestination, opening the canonical detail view.
    @Published var navigateToActiveLiveSession: LiveCash? = nil
    @Published var navigateToActiveOnlineSession: OnlineCash? = nil

    // True while the user is viewing the active session's detail screen,
    // so the floating bar hides itself (it would be redundant).
    @Published var isViewingActiveSessionDetail: Bool = false

    func openCashGame() {
        pendingGameCategory = .cashGame
        isFormPresented = true
    }

    func dismissForm() {
        isFormPresented = false
        pendingGameCategory = nil
    }
}
