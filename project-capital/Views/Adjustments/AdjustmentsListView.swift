import SwiftUI
import CoreData

struct AdjustmentsListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("baseCurrency") private var baseCurrency = "CAD"

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Adjustment.date, ascending: false)],
        animation: .default
    ) private var adjustments: FetchedResults<Adjustment>

    @State private var showAddAdjustment = false
    @State private var adjustmentToDelete: Adjustment? = nil
    @State private var showDeleteAlert = false

    var totalBase: Double {
        adjustments.reduce(0) { $0 + $1.amountBase }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    if !adjustments.isEmpty {
                        totalBar
                    }
                    if adjustments.isEmpty {
                        emptyState
                    } else {
                        adjustmentList
                    }
                }
            }
            .navigationTitle("Adjustments")
            .navigationBarTitleDisplayMode(.large)
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
            .alert("Delete Adjustment?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let a = adjustmentToDelete {
                        viewContext.delete(a)
                        try? viewContext.save()
                        adjustmentToDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) { adjustmentToDelete = nil }
            } message: {
                Text("This cannot be undone.")
            }
        }
    }

    var totalBar: some View {
        HStack {
            Text("Total")
                .font(.subheadline)
                .foregroundColor(.appSecondary)
            Spacer()
            Text(AppFormatter.currencySigned(totalBase, code: baseCurrency))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(totalBase.profitColor)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.appSurface)
    }

    var adjustmentList: some View {
        List {
            ForEach(Array(adjustments)) { adjustment in
                AdjustmentRowView(adjustment: adjustment, baseCurrency: baseCurrency)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            adjustmentToDelete = adjustment
                            showDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
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
            Text("Track rakeback, bonuses, and other adjustments")
                .font(.subheadline)
                .foregroundColor(.appSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
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
                        Text("·")
                            .foregroundColor(.appSecondary)
                        Text(platform.displayName)
                            .font(.caption)
                            .foregroundColor(.appSecondary)
                    } else if let location = adjustment.location, !location.isEmpty {
                        Text("·")
                            .foregroundColor(.appSecondary)
                        Text(location)
                            .font(.caption)
                            .foregroundColor(.appSecondary)
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
