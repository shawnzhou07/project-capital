import SwiftUI
import CoreData
import Combine

struct FloatingSessionBar: View {
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

    @State private var tick = Date()
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var session: (type: String, label: String, startTime: Date?)? {
        if let live = activeLive.first {
            return ("Live", live.location?.isEmpty == false ? (live.location ?? "Live Session") : "Live Session", live.startTime)
        }
        if let online = activeOnline.first {
            return ("Online", online.platform?.displayName ?? "Online Session", online.startTime)
        }
        return nil
    }

    private var isVisible: Bool {
        session != nil && !coordinator.isFormPresented
    }

    var body: some View {
        if isVisible, let info = session {
            Button {
                coordinator.openActiveSession()
            } label: {
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color.appProfit)
                        .frame(width: 10, height: 10)

                    Text(info.type)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.appPrimary)

                    if info.label != "Live Session" && info.label != "Online Session" {
                        Text(info.label)
                            .font(.subheadline)
                            .foregroundColor(.appSecondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(elapsedText(from: info.startTime))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.appGold)
                        .monospacedDigit()
                }
                .padding(.horizontal, 16)
                .frame(height: 56)
                .background(Color.appSurface)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: -2)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            .onReceive(timer) { _ in tick = Date() }
        }
    }

    private func elapsedText(from startTime: Date?) -> String {
        guard let start = startTime else { return "0h 0m" }
        let elapsed = tick.timeIntervalSince(start)
        let totalMinutes = max(0, Int(elapsed / 60))
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        return "\(h)h \(m)m"
    }
}
