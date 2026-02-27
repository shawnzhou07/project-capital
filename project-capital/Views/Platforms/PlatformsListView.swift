import SwiftUI
import CoreData

struct PlatformsListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("baseCurrency") private var baseCurrency = "CAD"
    @EnvironmentObject var coordinator: ActiveSessionCoordinator

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Platform.name, ascending: true)],
        animation: .default
    ) private var platforms: FetchedResults<Platform>

    @State private var showAddPlatform = false
    @State private var platformToDelete: Platform? = nil
    @State private var showDeleteAlert = false
    @State private var externalDepositPlatform: Platform? = nil
    @State private var externalWithdrawalPlatform: Platform? = nil
    @State private var showExternalDeposit = false
    @State private var showExternalWithdrawal = false

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
        .sheet(isPresented: $showExternalDeposit) {
            if let p = externalDepositPlatform {
                DepositFormView(platform: p)
            }
        }
        .sheet(isPresented: $showExternalWithdrawal) {
            if let p = externalWithdrawalPlatform {
                WithdrawalFormView(platform: p)
            }
        }
        .onAppear { handleCoordinatorTriggers() }
        .onChange(of: coordinator.shouldOpenAddPlatform) { _, v in
            if v { showAddPlatform = true; coordinator.shouldOpenAddPlatform = false }
        }
        .onChange(of: coordinator.platformIDForDeposit) { _, _ in handleCoordinatorTriggers() }
        .onChange(of: coordinator.platformIDForWithdrawal) { _, _ in handleCoordinatorTriggers() }
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

    func handleCoordinatorTriggers() {
        if coordinator.shouldOpenAddPlatform {
            showAddPlatform = true
            coordinator.shouldOpenAddPlatform = false
        }
        if let id = coordinator.platformIDForDeposit,
           let platform = platforms.first(where: { $0.objectID == id }) {
            externalDepositPlatform = platform
            showExternalDeposit = true
            coordinator.platformIDForDeposit = nil
        }
        if let id = coordinator.platformIDForWithdrawal,
           let platform = platforms.first(where: { $0.objectID == id }) {
            externalWithdrawalPlatform = platform
            showExternalWithdrawal = true
            coordinator.platformIDForWithdrawal = nil
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

    var netResultColor: Color {
        platform.netResult.profitColor
    }

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
                Text(AppFormatter.currencySigned(platform.netResult, code: baseCurrency))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(netResultColor)
                if !isSameCurrency {
                    Text(AppFormatter.currency(platform.currentBalance, code: platform.displayCurrency))
                        .font(.caption)
                        .foregroundColor(.appSecondary)
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
