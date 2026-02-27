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

    // Lock in the session reference on first appear so the view doesn't
    // switch to CashGameTypePickerView after the user taps Stop (which
    // removes the session from the active fetch results).
    @State private var lockedLive: LiveCash? = nil
    @State private var lockedOnline: OnlineCash? = nil

    var body: some View {
        NavigationStack {
            routedContent
        }
        .onAppear {
            // Capture only once and only for existing-session re-entry
            if lockedLive == nil && lockedOnline == nil && coordinator.pendingGameCategory != .cashGame {
                lockedLive = activeLive.first
                lockedOnline = activeOnline.first
            }
        }
    }

    @ViewBuilder
    private var routedContent: some View {
        if coordinator.pendingGameCategory == .cashGame {
            // New cash game flow — shown even after Start is pressed,
            // so the NavigationStack root stays stable while the form is pushed on top.
            CashGameTypePickerView()
        } else if let live = lockedLive ?? activeLive.first {
            // Re-expanding a minimized live session — use locked reference
            // so the view stays stable after Stop is pressed
            LiveSessionEntryView(existingSession: live)
        } else if let online = lockedOnline ?? activeOnline.first {
            // Re-expanding a minimized online session
            OnlineSessionEntryView(existingSession: online)
        } else {
            // Fallback — should not normally occur
            CashGameTypePickerView()
        }
    }
}
