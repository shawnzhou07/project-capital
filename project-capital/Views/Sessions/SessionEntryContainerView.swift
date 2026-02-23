import SwiftUI
import CoreData

struct SessionEntryContainerView: View {
    @EnvironmentObject var coordinator: ActiveSessionCoordinator
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [],
        predicate: NSPredicate(format: "startTime != nil AND endTime == nil"),
        animation: .default
    ) private var activeLive: FetchedResults<LiveCash>

    @FetchRequest(
        sortDescriptors: [],
        predicate: NSPredicate(format: "startTime != nil AND endTime == nil"),
        animation: .default
    ) private var activeOnline: FetchedResults<OnlineCash>

    var body: some View {
        NavigationStack {
            routedContent
        }
    }

    @ViewBuilder
    private var routedContent: some View {
        if coordinator.pendingGameCategory == .cashGame {
            // New cash game flow — shown even after Start is pressed,
            // so the NavigationStack root stays stable while the form is pushed on top.
            CashGameTypePickerView()
        } else if let live = activeLive.first {
            // Re-expanding a minimized live session from the floating bar
            LiveSessionEntryView(existingSession: live)
        } else if let online = activeOnline.first {
            // Re-expanding a minimized online session from the floating bar
            OnlineSessionEntryView(existingSession: online)
        } else {
            // Fallback — should not normally occur
            CashGameTypePickerView()
        }
    }
}
