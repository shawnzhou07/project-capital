import SwiftUI
import CoreData

struct StatsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("baseCurrency") private var baseCurrency = "CAD"

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \OnlineCash.startTime, ascending: false)])
    private var onlineSessions: FetchedResults<OnlineCash>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \LiveCash.startTime, ascending: false)])
    private var liveSessions: FetchedResults<LiveCash>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Adjustment.date, ascending: false)])
    private var adjustments: FetchedResults<Adjustment>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Platform.name, ascending: true)])
    private var platforms: FetchedResults<Platform>

    @State private var dateFilter: DateFilter = .allTime
    @State private var sessionFilter: SessionFilter = .all
    @State private var includeAdjustments = true

    var stats: StatsResult {
        computeStats(
            online: Array(onlineSessions),
            live: Array(liveSessions),
            adjustments: Array(adjustments),
            dateFilter: dateFilter,
            sessionFilter: sessionFilter,
            showAdjustments: includeAdjustments
        )
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    netResultHeader
                    dateFilterBar
                    sessionFilterBar
                    statsGrid
                    if stats.totalHands > 0 {
                        bbStatsSection
                    }
                    platformBreakdown
                }
                .padding()
            }
        }
        .navigationTitle("Statistics")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Net Result Header

    var netResultHeader: some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                Text(baseCurrency)
                    .font(.caption).foregroundColor(.appSecondary)
                Text(AppFormatter.currencySigned(stats.netResult))
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(stats.netResult.profitColor)
                    .minimumScaleFactor(0.5)
            }

            Toggle(isOn: $includeAdjustments) {
                Text("Include Adjustments")
                    .font(.caption).foregroundColor(.appSecondary)
            }
            .tint(.appGold)
            .padding(.horizontal, 4)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.appSurface)
        .cornerRadius(8)
    }

    // MARK: - Date Filter Bar

    var dateFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                DateFilterChip(label: "All Time", isSelected: isDateFilter(.allTime)) { dateFilter = .allTime }
                DateFilterChip(label: "This Month", isSelected: isDateFilter(.thisMonth)) { dateFilter = .thisMonth }
                DateFilterChip(label: "This Year", isSelected: isDateFilter(.thisYear)) { dateFilter = .thisYear }
            }
        }
    }

    func isDateFilter(_ f: DateFilter) -> Bool {
        switch (dateFilter, f) {
        case (.allTime, .allTime), (.thisMonth, .thisMonth), (.thisYear, .thisYear): return true
        default: return false
        }
    }

    // MARK: - Session Filter Bar

    var sessionFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                SessionFilterChip(label: "All", isSelected: isFilter(.all)) { sessionFilter = .all }
                SessionFilterChip(label: "Live", isSelected: isFilter(.live)) { sessionFilter = .live }
                SessionFilterChip(label: "Online", isSelected: isFilter(.online)) { sessionFilter = .online }
                ForEach(Array(platforms)) { platform in
                    SessionFilterChip(
                        label: platform.displayName,
                        isSelected: isFilter(.platform(platform))
                    ) {
                        sessionFilter = .platform(platform)
                    }
                }
            }
        }
    }

    func isFilter(_ f: SessionFilter) -> Bool {
        switch (sessionFilter, f) {
        case (.all, .all), (.live, .live), (.online, .online): return true
        case (.platform(let a), .platform(let b)): return a == b
        default: return false
        }
    }

    // MARK: - Stats Grid

    var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(
                title: "Hourly Rate",
                value: AppFormatter.hourlyRate(stats.hourlyRate),
                icon: "clock.fill",
                color: stats.sessionCount == 0 ? .appSecondary : stats.hourlyRate.profitColor
            )
            StatCard(
                title: "Sessions",
                value: "\(stats.sessionCount)",
                icon: "calendar",
                color: .appGold
            )
            StatCard(
                title: "Hours Played",
                value: AppFormatter.duration(stats.totalHours),
                icon: "timer",
                color: .appGold
            )
            StatCard(
                title: "Hands Played",
                value: AppFormatter.handsCount(stats.totalHands),
                icon: "suit.spade.fill",
                color: .appGold
            )
            StatCard(
                title: "Avg Session",
                value: AppFormatter.currencySigned(stats.avgResult),
                icon: "chart.line.uptrend.xyaxis",
                color: stats.sessionCount == 0 ? .appSecondary : stats.avgResult.profitColor
            )
            StatCard(
                title: "Win Rate",
                value: AppFormatter.percentage(stats.winRate),
                icon: "trophy.fill",
                color: stats.sessionCount == 0 ? .appSecondary : (stats.winRate > 0.5 ? .appProfit : .appLoss)
            )
        }
    }

    // MARK: - BB Stats Section

    var bbStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Big Blind Tracking")
                .font(.headline).foregroundColor(.appGold)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(
                    title: "BB Net",
                    value: bbSigned(stats.totalBBWon) + " BB",
                    icon: "b.circle.fill",
                    color: stats.totalBBWon == 0 ? .appSecondary : stats.totalBBWon.profitColor
                )
                StatCard(
                    title: "BB / Hour",
                    value: bbSigned(stats.bbPerHour),
                    icon: "clock.fill",
                    color: stats.bbPerHour == 0 ? .appSecondary : stats.bbPerHour.profitColor
                )
                StatCard(
                    title: "BB / 100",
                    value: bbSigned(stats.bbPer100),
                    icon: "suit.spade.fill",
                    color: stats.bbPer100 == 0 ? .appSecondary : stats.bbPer100.profitColor
                )
            }
        }
    }

    func bbSigned(_ value: Double) -> String {
        let formatted = AppFormatter.bbValue(abs(value))
        if value > 0 { return "+\(formatted)" }
        if value < 0 { return "-\(formatted)" }
        return formatted
    }

    // MARK: - Platform Breakdown

    var platformBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Platform Breakdown")
                .font(.headline).foregroundColor(.appGold)

            if platforms.isEmpty {
                Text("No platforms added yet.")
                    .font(.subheadline).foregroundColor(.appSecondary)
                    .padding().frame(maxWidth: .infinity)
                    .background(Color.appSurface).cornerRadius(8)
            } else {
                ForEach(Array(platforms)) { platform in
                    PlatformBreakdownRow(platform: platform, baseCurrency: baseCurrency)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).foregroundColor(color).font(.caption)
                Spacer()
            }
            Text(value)
                .font(.title3).fontWeight(.bold).foregroundColor(color)
                .minimumScaleFactor(0.6).lineLimit(1)
            Text(title)
                .font(.caption).foregroundColor(.appSecondary)
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(8)
    }
}

struct PlatformBreakdownRow: View {
    let platform: Platform
    let baseCurrency: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(platform.displayName)
                    .font(.subheadline).fontWeight(.medium).foregroundColor(.appPrimary)
                HStack(spacing: 8) {
                    Text("Balance: \(AppFormatter.currency(platform.currentBalance, code: platform.displayCurrency))")
                        .font(.caption).foregroundColor(.appSecondary)
                    Text("·").foregroundColor(.appBorder)
                    Text("\(platform.onlineSessionsArray.count) sessions")
                        .font(.caption).foregroundColor(.appSecondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(AppFormatter.currencySigned(platform.netResult))
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(platform.netResult.profitColor)
                Text("net result")
                    .font(.caption2).foregroundColor(.appSecondary)
            }
        }
        .padding().background(Color.appSurface).cornerRadius(8)
    }
}

struct DateFilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .black : .appSecondary)
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(isSelected ? Color.appGold : Color.appSurface2)
                .cornerRadius(16)
        }
    }
}

struct SessionFilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .black : .appSecondary)
                .padding(.horizontal, 12).padding(.vertical, 6)
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
    StatsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .preferredColorScheme(.dark)
}
