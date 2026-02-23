import Foundation
import Combine

class ActiveSessionCoordinator: ObservableObject {

    enum GameCategory {
        case cashGame
        // Future: case tournament, sitngo, ...
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
