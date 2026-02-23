import SwiftUI
import CoreData

struct PlatformDetailView: View {
    @ObservedObject var platform: Platform
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("baseCurrency") private var baseCurrency = "CAD"

    @State private var balanceStr = ""
    @State private var showDeposit = false
    @State private var showWithdrawal = false
    @State private var showDeleteAlert = false
    @State private var loaded = false
    @State private var depositToDelete: Deposit? = nil
    @State private var withdrawalToDelete: Withdrawal? = nil
    @State private var showDepositDeleteAlert = false
    @State private var showWithdrawalDeleteAlert = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    balanceCard
                    actionButtons
                    sessionsSection
                    depositsSection
                    withdrawalsSection
                    dangerZone
                }
                .padding()
            }
        }
        .navigationTitle(platform.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !loaded {
                balanceStr = String(format: "%.2f", platform.currentBalance)
                loaded = true
            }
        }
        .sheet(isPresented: $showDeposit) {
            DepositFormView(platform: platform)
        }
        .sheet(isPresented: $showWithdrawal) {
            WithdrawalFormView(platform: platform)
        }
        .alert("Delete Platform?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                viewContext.delete(platform)
                try? viewContext.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete all associated sessions, deposits, and withdrawals. This cannot be undone.")
        }
        .alert("Delete Deposit?", isPresented: $showDepositDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let d = depositToDelete {
                    viewContext.delete(d)
                    try? viewContext.save()
                    depositToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { depositToDelete = nil }
        } message: { Text("This cannot be undone.") }
        .alert("Delete Withdrawal?", isPresented: $showWithdrawalDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let w = withdrawalToDelete {
                    viewContext.delete(w)
                    try? viewContext.save()
                    withdrawalToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { withdrawalToDelete = nil }
        } message: { Text("This cannot be undone.") }
    }

    // MARK: - Balance Card

    var balanceCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Balance")
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("$")
                            .font(.title3)
                            .foregroundColor(.appSecondary)
                        TextField("0.00", text: $balanceStr, onCommit: saveBalance)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.appPrimary)
                            .keyboardType(.decimalPad)
                            .fixedSize()
                        Text(platform.displayCurrency)
                            .font(.subheadline)
                            .foregroundColor(.appSecondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Net Result")
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                    Text(AppFormatter.currencySigned(platform.netResult))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(platform.netResult.profitColor)
                    Text(baseCurrency)
                        .font(.caption2)
                        .foregroundColor(.appSecondary)
                }
            }

            Divider().background(Color.appBorder)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Deposited")
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                    Text(AppFormatter.currency(platform.totalDeposited, code: baseCurrency))
                        .font(.subheadline)
                        .foregroundColor(.appPrimary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Total Withdrawn")
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                    Text(AppFormatter.currency(platform.totalWithdrawn, code: baseCurrency))
                        .font(.subheadline)
                        .foregroundColor(.appPrimary)
                }
            }
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(8)
    }

    // MARK: - Action Buttons

    var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                showDeposit = true
            } label: {
                Label("Deposit", systemImage: "arrow.down.circle.fill")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.appProfit)
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(Color.appSurface)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appProfit.opacity(0.4), lineWidth: 1))
            }
            Button {
                showWithdrawal = true
            } label: {
                Label("Withdraw", systemImage: "arrow.up.circle.fill")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.appLoss)
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(Color.appSurface)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appLoss.opacity(0.4), lineWidth: 1))
            }
        }
    }

    // MARK: - Sessions Section

    var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Sessions")
                    .font(.headline)
                    .foregroundColor(.appGold)
                Spacer()
                Text("\(platform.onlineSessionsArray.count)")
                    .font(.caption)
                    .foregroundColor(.appSecondary)
            }

            if platform.onlineSessionsArray.isEmpty {
                Text("No sessions recorded for this platform.")
                    .font(.caption)
                    .foregroundColor(.appSecondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.appSurface)
                    .cornerRadius(8)
            } else {
                ForEach(platform.onlineSessionsArray.prefix(5)) { session in
                    NavigationLink {
                        OnlineSessionDetailView(session: session)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(AppFormatter.shortDate(session.sessionDate))
                                    .font(.caption)
                                    .foregroundColor(.appSecondary)
                                Text("\(session.displayGameType) \(session.displayBlinds)")
                                    .font(.subheadline)
                                    .foregroundColor(.appPrimary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(AppFormatter.currencySigned(session.netProfitLoss, code: platform.displayCurrency))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(session.netProfitLoss.profitColor)
                                Text(AppFormatter.duration(session.computedDuration))
                                    .font(.caption)
                                    .foregroundColor(.appSecondary)
                            }
                        }
                        .padding()
                        .background(Color.appSurface)
                        .cornerRadius(8)
                    }
                }
            }
        }
    }

    // MARK: - Deposits Section

    var depositsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Deposits")
                .font(.headline)
                .foregroundColor(.appGold)

            if platform.depositsArray.isEmpty {
                Text("No deposits recorded.")
                    .font(.caption)
                    .foregroundColor(.appSecondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.appSurface)
                    .cornerRadius(8)
            } else {
                ForEach(platform.depositsArray.reversed()) { deposit in
                    DepositRowView(deposit: deposit, platformCurrency: platform.displayCurrency)
                        .contextMenu {
                            Button(role: .destructive) {
                                depositToDelete = deposit
                                showDepositDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }

    // MARK: - Withdrawals Section

    var withdrawalsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Withdrawals")
                .font(.headline)
                .foregroundColor(.appGold)

            if platform.withdrawalsArray.isEmpty {
                Text("No withdrawals recorded.")
                    .font(.caption)
                    .foregroundColor(.appSecondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.appSurface)
                    .cornerRadius(8)
            } else {
                ForEach(platform.withdrawalsArray.reversed()) { withdrawal in
                    WithdrawalRowView(withdrawal: withdrawal, platformCurrency: platform.displayCurrency)
                        .contextMenu {
                            Button(role: .destructive) {
                                withdrawalToDelete = withdrawal
                                showWithdrawalDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }

    // MARK: - Danger Zone

    var dangerZone: some View {
        Button(role: .destructive) {
            showDeleteAlert = true
        } label: {
            Text("Delete Platform")
                .font(.subheadline)
                .foregroundColor(.appLoss)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.appSurface)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appLoss.opacity(0.3), lineWidth: 1))
        }
    }

    func saveBalance() {
        platform.currentBalance = Double(balanceStr) ?? platform.currentBalance
        try? viewContext.save()
    }
}

struct DepositRowView: View {
    let deposit: Deposit
    let platformCurrency: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(.appProfit)
                        .font(.caption)
                    Text(AppFormatter.shortDate(deposit.date ?? Date()))
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                    Text("·")
                        .foregroundColor(.appSecondary)
                    Text(deposit.method ?? "—")
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                }
                Text(deposit.isForeignExchange ? "FX Transfer" : "Direct Deposit")
                    .font(.caption2)
                    .foregroundColor(.appSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("+\(AppFormatter.currency(deposit.amountReceived, code: platformCurrency))")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.appProfit)
                Text("-\(AppFormatter.currency(deposit.amountSent))")
                    .font(.caption)
                    .foregroundColor(.appSecondary)
            }
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(8)
    }
}

struct WithdrawalRowView: View {
    let withdrawal: Withdrawal
    let platformCurrency: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(.appLoss)
                        .font(.caption)
                    Text(AppFormatter.shortDate(withdrawal.date ?? Date()))
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                    Text("·")
                        .foregroundColor(.appSecondary)
                    Text(withdrawal.method ?? "—")
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                }
                Text(withdrawal.isForeignExchange ? "FX Withdrawal" : "Direct Withdrawal")
                    .font(.caption2)
                    .foregroundColor(.appSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("-\(AppFormatter.currency(withdrawal.amountRequested, code: platformCurrency))")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.appLoss)
                Text("+\(AppFormatter.currency(withdrawal.amountReceived))")
                    .font(.caption)
                    .foregroundColor(.appSecondary)
            }
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(8)
    }
}
