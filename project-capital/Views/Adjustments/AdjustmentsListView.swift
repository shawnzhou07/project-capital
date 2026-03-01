import SwiftUI
import CoreData

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
    @State private var dateFilter: AdjDateFilter = .allTime

    var filteredAdjustments: [Adjustment] {
        var result = Array(adjustments)

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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AdjDateFilter.allCases, id: \.self) { f in
                    FilterChip(label: f.rawValue, isSelected: dateFilter == f) {
                        dateFilter = f
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
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
            Text("Record balance corrections for your online platforms")
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
            Text("No adjustments in this period")
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
                    if let platform = adjustment.platform {
                        Text("·").foregroundColor(.appSecondary)
                        Text(platform.displayName).font(.caption).foregroundColor(.appSecondary)
                    }
                }
            }
            Spacer()
            let adjCurrency = adjustment.currency ?? baseCurrency
            VStack(alignment: .trailing, spacing: 2) {
                Text(AppFormatter.currencySigned(adjustment.amount, code: adjCurrency))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(adjustment.amount.profitColor)
                if adjCurrency != baseCurrency {
                    Text(AppFormatter.currencySigned(adjustment.amountBase, code: baseCurrency))
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                } else {
                    Text(" ").font(.caption).foregroundColor(.clear)
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
