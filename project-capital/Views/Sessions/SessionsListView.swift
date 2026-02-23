import SwiftUI
import CoreData
import Combine

struct SessionsListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var sessionCoordinator: ActiveSessionCoordinator
    @AppStorage("baseCurrency") private var baseCurrency = "CAD"

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \OnlineCash.startTime, ascending: false)],
        animation: .default
    ) private var onlineSessions: FetchedResults<OnlineCash>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \LiveCash.startTime, ascending: false)],
        animation: .default
    ) private var liveSessions: FetchedResults<LiveCash>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Platform.name, ascending: true)],
        animation: .default
    ) private var platforms: FetchedResults<Platform>

    @FetchRequest(
        sortDescriptors: [],
        predicate: NSPredicate(format: "startTime != nil AND endTime == nil"),
        animation: .default
    ) private var activeLiveSessions: FetchedResults<LiveCash>

    @FetchRequest(
        sortDescriptors: [],
        predicate: NSPredicate(format: "startTime != nil AND endTime == nil"),
        animation: .default
    ) private var activeOnlineSessions: FetchedResults<OnlineCash>

    @State private var showActiveSessionAlert = false
    @State private var filterType: FilterType = .all
    @State private var selectedPlatformFilter: Platform? = nil
    @State private var selectedGameTypeFilter: String? = nil
    @State private var deleteOnlineSession: OnlineCash? = nil
    @State private var deleteLiveSession: LiveCash? = nil
    @State private var showDeleteAlert = false

    enum FilterType: String, CaseIterable {
        case all = "All"
        case live = "Live"
        case online = "Online"
    }

    var allSessions: [SessionListItem] {
        var result: [SessionListItem] = []
        for s in onlineSessions {
            if shouldInclude(online: s) {
                result.append(SessionListItem(id: s.id ?? UUID(), date: s.sessionDate, kind: .online(s)))
            }
        }
        for s in liveSessions {
            if shouldInclude(live: s) {
                result.append(SessionListItem(id: s.id ?? UUID(), date: s.sessionDate, kind: .live(s)))
            }
        }
        return result.sorted { $0.date > $1.date }
    }

    func shouldInclude(online s: OnlineCash) -> Bool {
        switch filterType {
        case .live: return false
        case .online, .all: break
        }
        if let p = selectedPlatformFilter, s.platform != p { return false }
        if let gt = selectedGameTypeFilter, s.gameType != gt { return false }
        return true
    }

    func shouldInclude(live s: LiveCash) -> Bool {
        switch filterType {
        case .online: return false
        case .live, .all: break
        }
        if selectedPlatformFilter != nil { return false }
        if let gt = selectedGameTypeFilter, s.gameType != gt { return false }
        return true
    }

    var groupedSessions: [(key: String, sessions: [SessionListItem])] {
        var groups: [String: [SessionListItem]] = [:]
        for item in allSessions {
            let key = AppFormatter.monthYear(item.date)
            groups[key, default: []].append(item)
        }
        return groups.map { (key: $0.key, sessions: $0.value) }
            .sorted { a, b in
                let df = DateFormatter()
                df.dateFormat = "MMMM yyyy"
                let da = df.date(from: a.key) ?? .distantPast
                let db = df.date(from: b.key) ?? .distantPast
                return da > db
            }
    }

    var uniqueGameTypes: [String] {
        var types = Set<String>()
        onlineSessions.compactMap { $0.gameType }.forEach { types.insert($0) }
        liveSessions.compactMap { $0.gameType }.forEach { types.insert($0) }
        return types.sorted()
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                filterBar
                sessionList
            }
        }
        .navigationTitle("Sessions")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        handleAddTap()
                    } label: {
                        Label("Cash Game", systemImage: "suit.spade.fill")
                    }
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(.appGold)
                }
            }
        }
        .alert("Active Session", isPresented: $showActiveSessionAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You have an active session in progress. Please complete or discard it before starting a new one.")
        }
        .alert("Delete Session?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                performDelete()
            }
            Button("Cancel", role: .cancel) {
                deleteOnlineSession = nil
                deleteLiveSession = nil
            }
        } message: {
            Text("This cannot be undone.")
        }
    }

    var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FilterType.allCases, id: \.self) { type in
                    FilterChip(
                        label: type.rawValue,
                        isSelected: filterType == type && selectedPlatformFilter == nil && selectedGameTypeFilter == nil
                    ) {
                        filterType = type
                        selectedPlatformFilter = nil
                        selectedGameTypeFilter = nil
                    }
                }
                if filterType == .online || filterType == .all {
                    ForEach(Array(platforms), id: \.id) { platform in
                        FilterChip(
                            label: platform.displayName,
                            isSelected: selectedPlatformFilter == platform
                        ) {
                            selectedPlatformFilter = selectedPlatformFilter == platform ? nil : platform
                            selectedGameTypeFilter = nil
                        }
                    }
                }
                ForEach(uniqueGameTypes, id: \.self) { gt in
                    FilterChip(
                        label: gt,
                        isSelected: selectedGameTypeFilter == gt
                    ) {
                        selectedGameTypeFilter = selectedGameTypeFilter == gt ? nil : gt
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color.appBackground)
    }

    var sessionList: some View {
        List {
            if allSessions.isEmpty {
                emptyState
            } else {
                ForEach(groupedSessions, id: \.key) { group in
                    Section {
                        ForEach(group.sessions) { item in
                            sessionRow(item)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        switch item.kind {
                                        case .online(let s): deleteOnlineSession = s
                                        case .live(let s): deleteLiveSession = s
                                        }
                                        showDeleteAlert = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        Text(group.key)
                            .font(.headline)
                            .foregroundColor(.appGold)
                            .textCase(nil)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .refreshable {
            // Triggers FetchRequest re-evaluation
        }
    }

    @ViewBuilder
    func sessionRow(_ item: SessionListItem) -> some View {
        switch item.kind {
        case .online(let s):
            NavigationLink {
                OnlineSessionDetailView(session: s)
            } label: {
                SessionRowView(
                    date: s.sessionDate,
                    icon: "desktopcomputer",
                    title: s.platformName,
                    subtitle: "\(s.displayGameType) \(s.displayBlinds)",
                    duration: s.computedDuration,
                    netResult: s.netProfitLossBase,
                    currency: baseCurrency,
                    isActive: s.isActive
                )
            }
            .listRowBackground(Color.appSurface)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        case .live(let s):
            NavigationLink {
                LiveSessionDetailView(session: s)
            } label: {
                SessionRowView(
                    date: s.sessionDate,
                    icon: "building.columns",
                    title: s.displayLocation,
                    subtitle: "\(s.displayGameType) \(s.displayBlinds)",
                    duration: s.computedDuration,
                    netResult: s.netProfitLossBase,
                    currency: baseCurrency,
                    isActive: s.isActive
                )
            }
            .listRowBackground(Color.appSurface)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        }
    }

    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "suit.spade")
                .font(.system(size: 48))
                .foregroundColor(.appSecondary)
            Text("No Sessions Yet")
                .font(.headline)
                .foregroundColor(.appPrimary)
            Text("Tap + to record your first session")
                .font(.subheadline)
                .foregroundColor(.appSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .listRowBackground(Color.appBackground)
        .listRowSeparator(.hidden)
    }

    func handleAddTap() {
        if !activeLiveSessions.isEmpty || !activeOnlineSessions.isEmpty {
            showActiveSessionAlert = true
        } else {
            sessionCoordinator.openCashGame()
        }
    }

    func performDelete() {
        if let s = deleteOnlineSession {
            viewContext.delete(s)
            deleteOnlineSession = nil
        }
        if let s = deleteLiveSession {
            viewContext.delete(s)
            deleteLiveSession = nil
        }
        do { try viewContext.save() } catch { print("Delete error: \(error)") }
    }
}

enum SessionKind {
    case online(OnlineCash)
    case live(LiveCash)
}

struct SessionListItem: Identifiable {
    let id: UUID
    let date: Date
    let kind: SessionKind
}

struct SessionRowView: View {
    let date: Date
    let icon: String
    let title: String
    let subtitle: String
    let duration: Double
    let netResult: Double
    let currency: String
    let isActive: Bool

    @State private var elapsed: TimeInterval = 0
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .center, spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.appGold)
                Text(AppFormatter.sessionDate(date))
                    .font(.caption2)
                    .foregroundColor(.appSecondary)
            }
            .frame(width: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.appPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.appSecondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(AppFormatter.currencySigned(netResult))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(netResult.profitColor)
                if isActive {
                    Text(AppFormatter.duration(elapsed / 3600))
                        .font(.caption)
                        .foregroundColor(.appGold)
                        .onReceive(timer) { _ in
                            elapsed += 1
                        }
                } else {
                    Text(AppFormatter.duration(duration))
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .black : .appSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.appGold : Color.appSurface2)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? Color.appGold : Color.appBorder, lineWidth: 1)
                )
        }
    }
}

#Preview {
    SessionsListView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ActiveSessionCoordinator())
        .preferredColorScheme(.dark)
}
