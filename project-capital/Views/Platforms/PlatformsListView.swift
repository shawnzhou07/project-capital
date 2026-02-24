import SwiftUI
import CoreData

struct PlatformsListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("baseCurrency") private var baseCurrency = "CAD"

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Platform.name, ascending: true)],
        animation: .default
    ) private var platforms: FetchedResults<Platform>

    @State private var showAddPlatform = false
    @State private var platformToDelete: Platform? = nil
    @State private var showDeleteAlert = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            if platforms.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(Array(platforms)) { platform in
                        NavigationLink {
                            PlatformDetailView(platform: platform)
                        } label: {
                            PlatformRowView(platform: platform, baseCurrency: baseCurrency)
                        }
                        .listRowBackground(Color.appSurface)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                platformToDelete = platform
                                showDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.appBackground)
            }
        }
        .navigationTitle("Platforms")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddPlatform = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(.appGold)
                }
            }
        }
        .sheet(isPresented: $showAddPlatform) {
            AddPlatformView()
        }
        .alert(deleteAlertTitle, isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let p = platformToDelete {
                    viewContext.delete(p)
                    try? viewContext.save()
                }
                platformToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                platformToDelete = nil
            }
        } message: {
            Text(deleteAlertMessage)
        }
    }

    var deleteAlertTitle: String {
        "Delete \(platformToDelete?.displayName ?? "Platform")?"
    }

    var deleteAlertMessage: String {
        guard let p = platformToDelete else { return "This cannot be undone." }
        let sessions = p.onlineSessionsArray.count
        let deposits = p.depositsArray.count
        let withdrawals = p.withdrawalsArray.count
        var parts: [String] = []
        if sessions > 0 { parts.append("\(sessions) session\(sessions == 1 ? "" : "s")") }
        if deposits > 0 { parts.append("\(deposits) deposit\(deposits == 1 ? "" : "s")") }
        if withdrawals > 0 { parts.append("\(withdrawals) withdrawal\(withdrawals == 1 ? "" : "s")") }
        if parts.isEmpty { return "This cannot be undone." }
        return "This will also delete \(parts.joined(separator: ", ")). This cannot be undone."
    }

    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "creditcard")
                .font(.system(size: 48))
                .foregroundColor(.appSecondary)
            Text("No Platforms")
                .font(.headline)
                .foregroundColor(.appPrimary)
            Text("Tap + to add your poker platforms")
                .font(.subheadline)
                .foregroundColor(.appSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PlatformRowView: View {
    let platform: Platform
    let baseCurrency: String

    var isSameCurrency: Bool { platform.displayCurrency == baseCurrency }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(platform.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.appPrimary)
                Text(platform.displayCurrency)
                    .font(.caption)
                    .foregroundColor(.appSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                if !isSameCurrency {
                    Text(AppFormatter.currency(platform.currentBalance, code: platform.displayCurrency))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.appPrimary)
                    Text(AppFormatter.currencySigned(platform.netResult) + " \(baseCurrency)")
                        .font(.caption)
                        .foregroundColor(platform.netResult.profitColor)
                } else {
                    Text(AppFormatter.currencySigned(platform.netResult) + " \(baseCurrency)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(platform.netResult.profitColor)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    PlatformsListView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .preferredColorScheme(.dark)
}
