import Foundation
import Combine
import SwiftUI

class ActiveSessionCoordinator: ObservableObject {

    enum GameCategory {
        case cashGame
    }

    @Published var isFormPresented = false
    @Published var pendingGameCategory: GameCategory? = nil

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
