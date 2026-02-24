import SwiftUI
import CoreData

private enum AdjTypeFilter: String, CaseIterable {
    case all = "All"
    case online = "Online"
    case live = "Live"
}

private enum AdjSignFilter: String, CaseIterable {
    case all = "All"
    case positive = "+"
    case negative = "−"
}

private enum AdjDateFilter: String, CaseIterable {
    case allTime = "All Time"
    case thisMonth = "This Month"
    case thisYear = "This Year"
}

struct AdjustmentsListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("baseCurrency") private var baseCurrency = "CAD"

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Adjustment.date, ascending: false)],
        animation: .default
    ) private var adjustments: FetchedResults<Adjustment>

    @State private var showAddAdjustment = false
    @State private var typeFilter: AdjTypeFilter = .all
    @State private var signFilter: AdjSignFilter = .all
    @State private var dateFilter: AdjDateFilter = .allTime

    var filteredAdjustments: [Adjustment] {
        var result = Array(adjustments)

        switch typeFilter {
        case .online: result = result.filter { $0.isOnline }
        case .live:   result = result.filter { !$0.isOnline }
        case .all:    break
        }

        switch signFilter {
        case .positive: result = result.filter { $0.amountBase > 0 }
        case .negative: result = result.filter { $0.amountBase < 0 }
        case .all:      break
        }

        let calendar = Calendar.current
        let now = Date()
        switch dateFilter {
        case .thisMonth:
            let comps = calendar.dateComponents([.year, .month], from: now)
            if let start = calendar.date(from: comps) {
                result = result.filter { ($0.date ?? Date.distantPast) >= start }
            }
        case .thisYear:
            let comps = calendar.dateComponents([.year], from: now)
            if let start = calendar.date(from: comps) {
                result = result.filter { ($0.date ?? Date.distantPast) >= start }
            }
        case .allTime: break
        }

        return result
    }

    var filteredTotal: Double {
        filteredAdjustments.reduce(0) { $0 + $1.amountBase }
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                filterBar
                if !filteredAdjustments.isEmpty {
                    totalBar
                }
                if adjustments.isEmpty {
                    emptyState
                } else if filteredAdjustments.isEmpty {
                    noResultsState
                } else {
                    adjustmentList
                }
            }
        }
        .navigationTitle("Adjustments")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddAdjustment = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(.appGold)
                }
            }
        }
        .sheet(isPresented: $showAddAdjustment) {
            AddAdjustmentView()
        }
    }

    var filterBar: some View {
        VStack(spacing: 6) {
            // Row 1: Type + Sign
            HStack(spacing: 8) {
                ForEach(AdjTypeFilter.allCases, id: \.self) { f in
                    FilterChip(label: f.rawValue, isSelected: typeFilter == f) {
                        typeFilter = f
                    }
                }
                Divider()
                    .frame(height: 20)
                    .background(Color.appBorder)
                ForEach(AdjSignFilter.allCases, id: \.self) { f in
                    FilterChip(label: f.rawValue, isSelected: signFilter == f) {
                        signFilter = f
                    }
                }
                Spacer()
            }
            .padding(.horizontal)

            // Row 2: Date
            HStack(spacing: 8) {
                ForEach(AdjDateFilter.allCases, id: \.self) { f in
                    FilterChip(label: f.rawValue, isSelected: dateFilter == f) {
                        dateFilter = f
                    }
                }
                Spacer()
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color.appBackground)
    }

    var totalBar: some View {
        HStack {
            Text("Total")
                .font(.subheadline)
                .foregroundColor(.appSecondary)
            Spacer()
            Text(AppFormatter.currencySigned(filteredTotal, code: baseCurrency))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(filteredTotal.profitColor)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.appSurface)
    }

    var adjustmentList: some View {
        List {
            ForEach(filteredAdjustments) { adjustment in
                NavigationLink {
                    AdjustmentDetailView(adjustment: adjustment)
                } label: {
                    AdjustmentRowView(adjustment: adjustment, baseCurrency: baseCurrency)
                }
                .listRowBackground(Color.appSurface)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
    }

    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "plusminus.circle")
                .font(.system(size: 48))
                .foregroundColor(.appSecondary)
            Text("No Adjustments")
                .font(.headline)
                .foregroundColor(.appPrimary)
            Text("Record financial corrections and miscellaneous entries")
                .font(.subheadline)
                .foregroundColor(.appSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    var noResultsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 40))
                .foregroundColor(.appSecondary)
            Text("No matching adjustments")
                .font(.subheadline)
                .foregroundColor(.appSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


struct AdjustmentRowView: View {
    let adjustment: Adjustment
    let baseCurrency: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(adjustment.name ?? "Adjustment")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.appPrimary)
                HStack(spacing: 6) {
                    Text(AppFormatter.shortDate(adjustment.date ?? Date()))
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                    if adjustment.isOnline, let platform = adjustment.platform {
                        Text("·").foregroundColor(.appSecondary)
                        Text(platform.displayName).font(.caption).foregroundColor(.appSecondary)
                    } else if let location = adjustment.location, !location.isEmpty {
                        Text("·").foregroundColor(.appSecondary)
                        Text(location).font(.caption).foregroundColor(.appSecondary)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(AppFormatter.currencySigned(adjustment.amountBase, code: baseCurrency))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(adjustment.amountBase.profitColor)
                if adjustment.currency != baseCurrency {
                    Text(AppFormatter.currencySigned(adjustment.amount, code: adjustment.currency ?? ""))
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    AdjustmentsListView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .preferredColorScheme(.dark)
}
