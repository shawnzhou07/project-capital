import SwiftUI
import CoreData
import Combine
import UIKit

struct LiveSessionDetailView: View {
    @ObservedObject var session: LiveCash
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("baseCurrency") private var baseCurrency = "CAD"
    @AppStorage("exchangeRateInputMode") private var exchangeRateInputMode = "direct"

    @State private var showDeleteAlert = false
    @State private var showVerifyAlert = false
    @Environment(\.dismiss) private var dismiss

    @State private var location = ""
    @State private var currency = "CAD"
    // Dual exchange rates
    @State private var exchangeRateBuyInStr = "1.0000"
    @State private var exchangeRateCashOutStr = "1.0000"
    // Mode B: amounts in base currency for each rate
    @State private var buyInBaseStr = ""
    @State private var cashOutBaseStr = ""
    @State private var gameType = "No Limit Hold'em"
    @State private var blinds = ""
    @State private var tableSize = 9
    @State private var startTime = Date()
    @State private var endTime = Date()
    @State private var buyIn = ""
    @State private var cashOut = ""
    @State private var tips = "0"
    @State private var handsOverride = ""
    @State private var notes = ""
    @State private var loaded = false
    @State private var elapsed: TimeInterval = 0
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var isSameCurrency: Bool { currency == baseCurrency }
    var duration: Double { endTime.timeIntervalSince(startTime) / 3600.0 }
    var buyInDouble: Double { Double(buyIn) ?? 0 }
    var cashOutDouble: Double { Double(cashOut) ?? 0 }
    var exchangeRateBuyIn: Double { Double(exchangeRateBuyInStr) ?? 1.0 }
    var exchangeRateCashOut: Double { Double(exchangeRateCashOutStr) ?? 1.0 }

    // Net result excludes tips
    var netPL: Double { cashOutDouble - buyInDouble }
    // Net in base uses cashOut rate (spec requirement)
    var netPLBase: Double { netPL * exchangeRateCashOut }
    var buyInBase: Double { buyInDouble * exchangeRateBuyIn }
    var cashOutBase: Double { cashOutDouble * exchangeRateCashOut }

    var estimatedHands: Int { Int(max(0, duration) * Double(UserSettings.shared.handsPerHourLive)) }

    var isVerified: Bool { session.isVerified }

    // All required fields for verification
    var canVerify: Bool {
        !location.trimmingCharacters(in: .whitespaces).isEmpty &&
        !gameType.isEmpty &&
        !blinds.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        mainContentWithAlerts
    }

    private var mainZStack: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            // Verified gold border overlay
            if isVerified {
                RoundedRectangle(cornerRadius: 0)
                    .stroke(Color.appGold.opacity(0.4), lineWidth: 1)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .zIndex(999)
            }

            VStack(spacing: 0) {
                Form {
                    headerSection
                    locationSection
                    gameDetailsSection
                    timingSection
                    financialsSection
                    if !isSameCurrency {
                        exchangeRatesSection
                    }
                    handsSection
                    notesSection
                    if !isVerified {
                        deleteSection
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.appBackground)

                // Bottom-pinned verify button or verified indicator
                verifyBar
            }
        }
    }

    private var mainContentWithOnChange: some View {
        mainZStack
            .navigationTitle("Live Session")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { loadFromSession() }
            .onChange(of: location) { _, _ in autoSave() }
            .onChange(of: currency) { _, _ in autoSave() }
            .onChange(of: exchangeRateBuyInStr) { _, _ in autoSave() }
            .onChange(of: exchangeRateCashOutStr) { _, _ in autoSave() }
            .onChange(of: buyInBaseStr) { _, _ in recalcRateFromAmounts(forBuyIn: true); autoSave() }
            .onChange(of: cashOutBaseStr) { _, _ in recalcRateFromAmounts(forBuyIn: false); autoSave() }
            .onChange(of: gameType) { _, _ in autoSave() }
            .onChange(of: blinds) { _, _ in autoSave() }
            .onChange(of: tableSize) { _, _ in autoSave() }
            .onChange(of: startTime) { _, _ in autoSave() }
            .onChange(of: endTime) { _, _ in autoSave() }
            .onChange(of: buyIn) { _, _ in autoSave() }
            .onChange(of: cashOut) { _, _ in autoSave() }
            .onChange(of: tips) { _, _ in autoSave() }
            .onChange(of: handsOverride) { _, _ in autoSave() }
            .onChange(of: notes) { _, _ in autoSave() }
    }

    private var mainContentWithAlerts: some View {
        mainContentWithOnChange
            .alert("Delete Session?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    viewContext.delete(session)
                    try? viewContext.save()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
            .alert("Verify Session?", isPresented: $showVerifyAlert) {
                Button("Verify") {
                    verifySession()
                }
                .foregroundStyle(Color.appGold)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Verify this session? Buy in, cash out, and currency will be permanently locked and cannot be changed.")
            }
    }

    // MARK: - Bottom Bar

    var verifyBar: some View {
        Group {
            if isVerified {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.appGold)
                        .font(.subheadline)
                    Text("Verified")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.appGold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.appBackground)
            } else {
                Button {
                    if canVerify { showVerifyAlert = true }
                } label: {
                    Text("Verify Session")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(canVerify ? .black : .appGold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            canVerify
                                ? Color.appGold
                                : Color.clear
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.appGold, lineWidth: canVerify ? 0 : 1.5)
                        )
                        .cornerRadius(12)
                        .opacity(canVerify ? 1.0 : 0.5)
                }
                .disabled(!canVerify)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.appBackground)
            }
        }
    }

    // MARK: - Header

    var headerSection: some View {
        Section {
            VStack(spacing: 8) {
                Text(AppFormatter.currencySigned(session.netProfitLossBase))
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(session.netProfitLossBase.profitColor)
                HStack(spacing: 16) {
                    Label(AppFormatter.duration(session.computedDuration), systemImage: "clock")
                    Label(AppFormatter.handsCount(session.effectiveHands) + " hands", systemImage: "suit.spade")
                }
                .font(.subheadline)
                .foregroundColor(.appSecondary)
                if session.isActive {
                    HStack {
                        Circle().fill(Color.appProfit).frame(width: 8, height: 8)
                        Text("Live — \(AppFormatter.duration(elapsed / 3600))")
                            .font(.caption).foregroundColor(.appProfit)
                    }
                    .onReceive(timer) { _ in elapsed += 1 }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .listRowBackground(Color.appSurface)
    }

    // MARK: - Location

    var locationSection: some View {
        Section {
            // Location field
            if isVerified {
                // Always editable even when verified
                HStack {
                    Text("Location").foregroundColor(.appPrimary)
                    Spacer()
                    TextField("Casino / location", text: $location)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.appGold)
                }
                .listRowBackground(Color.appSurface)
            } else {
                HStack {
                    Text("Location").foregroundColor(.appPrimary)
                    Spacer()
                    TextField("Casino / location", text: $location)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.appGold)
                }
                .listRowBackground(Color.appSurface)
            }

            // Currency — LOCKED when verified
            if isVerified {
                lockedRow(label: "Currency", value: currency)
            } else {
                Picker("Currency", selection: $currency) {
                    ForEach(supportedCurrencies, id: \.self) { Text($0).tag($0) }
                }
                .foregroundColor(.appPrimary)
                .tint(.appGold)
                .listRowBackground(Color.appSurface)
            }
        } header: {
            Text("Location").foregroundColor(.appGold).textCase(nil)
        }
    }

    // MARK: - Game Details (always editable)

    var gameDetailsSection: some View {
        Section {
            Picker("Game Type", selection: $gameType) {
                ForEach(gameTypes, id: \.self) { Text($0) }
            }
            .foregroundColor(.appPrimary)
            .listRowBackground(Color.appSurface)

            HStack {
                Text("Blinds").foregroundColor(.appPrimary)
                Spacer()
                TextField("$1/$2", text: $blinds)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.appGold)
            }
            .listRowBackground(Color.appSurface)

            Stepper("Table Size: \(tableSize)", value: $tableSize, in: 2...10)
                .foregroundColor(.appPrimary)
                .listRowBackground(Color.appSurface)
        } header: {
            Text("Game Details").foregroundColor(.appGold).textCase(nil)
        }
    }

    // MARK: - Timing (always editable)

    var timingSection: some View {
        Section {
            DatePicker("Start Time", selection: $startTime)
                .foregroundColor(.appPrimary).tint(.appGold)
                .listRowBackground(Color.appSurface)
            DatePicker("End Time", selection: $endTime)
                .foregroundColor(.appPrimary).tint(.appGold)
                .listRowBackground(Color.appSurface)
            HStack {
                Text("Duration").foregroundColor(.appPrimary)
                Spacer()
                Text(AppFormatter.duration(max(0, duration))).foregroundColor(.appSecondary)
            }
            .listRowBackground(Color.appSurface)
        } header: {
            Text("Timing").foregroundColor(.appGold).textCase(nil)
        }
    }

    // MARK: - Financials

    var financialsSection: some View {
        Section {
            // Buy In — LOCKED when verified
            if isVerified {
                lockedRow(label: "Buy In", value: "\(currency) \(String(format: "%.2f", buyInDouble))")
            } else {
                HStack {
                    Text("Buy In").foregroundColor(.appPrimary)
                    Spacer()
                    Text(currency).font(.caption).foregroundColor(.appSecondary)
                    TextField("0.00", text: $buyIn)
                        .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        .foregroundColor(.appPrimary).frame(width: 100)
                }
                .listRowBackground(Color.appSurface)
            }

            // Cash Out — LOCKED when verified
            if isVerified {
                lockedRow(label: "Cash Out", value: "\(currency) \(String(format: "%.2f", cashOutDouble))")
            } else {
                HStack {
                    Text("Cash Out").foregroundColor(.appPrimary)
                    Spacer()
                    Text(currency).font(.caption).foregroundColor(.appSecondary)
                    TextField("0.00", text: $cashOut)
                        .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        .foregroundColor(.appPrimary).frame(width: 100)
                }
                .listRowBackground(Color.appSurface)
            }

            // Tips (always editable)
            HStack {
                Text("Tips").foregroundColor(.appPrimary)
                Spacer()
                Text(currency).font(.caption).foregroundColor(.appSecondary)
                TextField("0.00", text: $tips)
                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    .foregroundColor(.appPrimary).frame(width: 100)
            }
            .listRowBackground(Color.appSurface)

            // Net Result
            HStack {
                Text("Net Result").foregroundColor(.appPrimary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(AppFormatter.currencySigned(netPL, code: currency))
                        .fontWeight(.semibold).foregroundColor(netPL.profitColor)
                    if !isSameCurrency {
                        Text(AppFormatter.currencySigned(netPLBase, code: baseCurrency))
                            .font(.caption).foregroundColor(netPLBase.profitColor)
                    }
                }
            }
            .listRowBackground(Color.appSurface)
        } header: {
            Text("Financials").foregroundColor(.appGold).textCase(nil)
        }
    }

    // MARK: - Exchange Rates (only for foreign currency sessions; always editable)

    var exchangeRatesSection: some View {
        Section {
            if exchangeRateInputMode == "direct" {
                // Mode A: Enter Rate Directly
                // Buy-In Rate
                HStack {
                    Text("Buy-In Rate")
                        .foregroundColor(.appPrimary)
                    Spacer()
                    TextField("1.0000", text: $exchangeRateBuyInStr)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.white)
                        .frame(width: 90)
                        .onChange(of: exchangeRateBuyInStr) { _, newVal in
                            // Auto-fill cash-out rate with same value if user hasn't customized it
                        }
                    Text("\(currency)/\(baseCurrency)")
                        .font(.caption).foregroundColor(.appSecondary)
                }
                .listRowBackground(Color.appSurface)

                // Buy-In cost (calculated, read-only)
                HStack {
                    Text("Buy-In Cost")
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                    Spacer()
                    Text(AppFormatter.currency(buyInBase, code: baseCurrency))
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                }
                .listRowBackground(Color.appSurface)
                .allowsHitTesting(false)

                // Cash-Out Rate
                HStack {
                    Text("Cash-Out Rate")
                        .foregroundColor(.appPrimary)
                    Spacer()
                    TextField("1.0000", text: $exchangeRateCashOutStr)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.white)
                        .frame(width: 90)
                    Text("\(currency)/\(baseCurrency)")
                        .font(.caption).foregroundColor(.appSecondary)
                }
                .listRowBackground(Color.appSurface)

                // Cash-Out proceeds (calculated, read-only)
                HStack {
                    Text("Cash-Out Proceeds")
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                    Spacer()
                    Text(AppFormatter.currency(cashOutBase, code: baseCurrency))
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                }
                .listRowBackground(Color.appSurface)
                .allowsHitTesting(false)

            } else {
                // Mode B: Enter Amounts
                // Buy-In section
                Text("Buy-In Exchange")
                    .font(.caption)
                    .foregroundColor(.appGold)
                    .listRowBackground(Color.appSurface)

                HStack {
                    Text("Amount (\(currency))")
                        .foregroundColor(.appPrimary)
                    Spacer()
                    TextField("0.00", text: $buyIn)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.white)
                        .frame(width: 100)
                        .disabled(isVerified)
                }
                .listRowBackground(Color.appSurface)

                HStack {
                    Text("Equivalent (\(baseCurrency))")
                        .foregroundColor(.appPrimary)
                    Spacer()
                    TextField("0.00", text: $buyInBaseStr)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.white)
                        .frame(width: 100)
                }
                .listRowBackground(Color.appSurface)

                // Calculated rate
                HStack {
                    Text("Rate (calculated)")
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                    Spacer()
                    Text(String(format: "%.4f", exchangeRateBuyIn))
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                    Text("\(currency)/\(baseCurrency)")
                        .font(.caption2)
                        .foregroundColor(.appSecondary)
                }
                .listRowBackground(Color.appSurface)
                .allowsHitTesting(false)

                // Cash-Out section
                Text("Cash-Out Exchange")
                    .font(.caption)
                    .foregroundColor(.appGold)
                    .listRowBackground(Color.appSurface)

                HStack {
                    Text("Amount (\(currency))")
                        .foregroundColor(.appPrimary)
                    Spacer()
                    TextField("0.00", text: $cashOut)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.white)
                        .frame(width: 100)
                        .disabled(isVerified)
                }
                .listRowBackground(Color.appSurface)

                HStack {
                    Text("Equivalent (\(baseCurrency))")
                        .foregroundColor(.appPrimary)
                    Spacer()
                    TextField("0.00", text: $cashOutBaseStr)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.white)
                        .frame(width: 100)
                }
                .listRowBackground(Color.appSurface)

                // Calculated cash-out rate
                HStack {
                    Text("Rate (calculated)")
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                    Spacer()
                    Text(String(format: "%.4f", exchangeRateCashOut))
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                    Text("\(currency)/\(baseCurrency)")
                        .font(.caption2)
                        .foregroundColor(.appSecondary)
                }
                .listRowBackground(Color.appSurface)
                .allowsHitTesting(false)
            }
        } header: {
            Text("Exchange Rates").foregroundColor(.appGold).textCase(nil)
        } footer: {
            Text("Exchange rates are always editable.")
                .foregroundColor(.appSecondary)
        }
    }

    // MARK: - Hands

    var handsSection: some View {
        Section {
            HStack {
                Text("Hands Played").foregroundColor(.appPrimary)
                Spacer()
                TextField("Auto (\(estimatedHands) est.)", text: $handsOverride)
                    .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                    .foregroundColor(.appGold).frame(width: 140)
            }
            .listRowBackground(Color.appSurface)
        } header: {
            Text("Hands").foregroundColor(.appGold).textCase(nil)
        }
    }

    // MARK: - Notes

    var notesSection: some View {
        Section {
            TextEditor(text: $notes)
                .frame(minHeight: 80).foregroundColor(.appPrimary)
                .scrollContentBackground(.hidden).background(Color.appSurface)
                .listRowBackground(Color.appSurface)
        } header: {
            Text("Notes").foregroundColor(.appGold).textCase(nil)
        }
    }

    // MARK: - Delete

    var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Text("Delete Session").frame(maxWidth: .infinity).foregroundColor(.appLoss)
            }
            .listRowBackground(Color.appSurface)
        }
    }

    // MARK: - Locked Field Row

    @ViewBuilder
    func lockedRow(label: String, value: String) -> some View {
        Button {
            triggerLockHaptic()
        } label: {
            HStack {
                Text(label).foregroundColor(.appPrimary)
                Spacer()
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundColor(.appGold)
                Text(value)
                    .foregroundColor(.appSecondary)
            }
        }
        .listRowBackground(Color.appSurface)
    }

    // MARK: - Helpers

    func triggerLockHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.impactOccurred()
    }

    func recalcRateFromAmounts(forBuyIn: Bool) {
        if forBuyIn {
            let amt = Double(buyIn) ?? 0
            let base = Double(buyInBaseStr) ?? 0
            if amt > 0 && base > 0 {
                exchangeRateBuyInStr = String(format: "%.4f", base / amt)
            }
        } else {
            let amt = Double(cashOut) ?? 0
            let base = Double(cashOutBaseStr) ?? 0
            if amt > 0 && base > 0 {
                exchangeRateCashOutStr = String(format: "%.4f", base / amt)
            }
        }
    }

    func verifySession() {
        session.isVerified = true
        autoSave()
    }

    func loadFromSession() {
        guard !loaded else { return }
        loaded = true
        location = session.location ?? ""
        currency = session.currency ?? baseCurrency
        gameType = session.gameType ?? "No Limit Hold'em"
        blinds = session.blinds ?? ""
        tableSize = Int(session.tableSize)
        startTime = session.startTime ?? Date()
        endTime = session.endTime ?? Date()
        buyIn = String(format: "%.2f", session.buyIn)
        cashOut = String(format: "%.2f", session.cashOut)
        tips = String(format: "%.2f", session.tips)
        handsOverride = session.handsCount > 0 ? "\(session.handsCount)" : ""
        notes = session.notes ?? ""

        // Load exchange rates
        if session.exchangeRateCashOut > 0 {
            exchangeRateBuyInStr = String(format: "%.4f", session.exchangeRateBuyIn > 0 ? session.exchangeRateBuyIn : session.exchangeRateCashOut)
            exchangeRateCashOutStr = String(format: "%.4f", session.exchangeRateCashOut)
        } else if session.exchangeRateToBase > 0 && session.exchangeRateToBase != 1.0 {
            exchangeRateBuyInStr = String(format: "%.4f", session.exchangeRateToBase)
            exchangeRateCashOutStr = String(format: "%.4f", session.exchangeRateToBase)
        } else {
            // Pre-fill from settings default
            let defaultRate = UserSettings.shared.defaultExchangeRate(sessionCurrency: session.currency ?? baseCurrency, baseCurrency: baseCurrency)
            exchangeRateBuyInStr = String(format: "%.4f", defaultRate)
            exchangeRateCashOutStr = String(format: "%.4f", defaultRate)
        }

        // Pre-fill Mode B base amounts
        if exchangeRateInputMode == "amounts" {
            let buyInAmt = session.buyIn
            let cashOutAmt = session.cashOut
            let rateBI = Double(exchangeRateBuyInStr) ?? 1.0
            let rateCO = Double(exchangeRateCashOutStr) ?? 1.0
            if buyInAmt > 0 { buyInBaseStr = String(format: "%.2f", buyInAmt * rateBI) }
            if cashOutAmt > 0 { cashOutBaseStr = String(format: "%.2f", cashOutAmt * rateCO) }
        }

        if session.isActive, let start = session.startTime {
            elapsed = Date().timeIntervalSince(start)
        }
    }

    func autoSave() {
        guard loaded else { return }
        if !isVerified {
            session.location = location
            session.currency = currency
            session.buyIn = Double(buyIn) ?? 0
            session.cashOut = Double(cashOut) ?? 0
        }
        // Exchange rates always saveable
        session.exchangeRateBuyIn = exchangeRateBuyIn
        session.exchangeRateCashOut = exchangeRateCashOut
        session.exchangeRateToBase = exchangeRateCashOut  // keep legacy field in sync

        session.gameType = gameType
        session.blinds = blinds
        session.tableSize = Int16(tableSize)
        session.startTime = startTime
        session.endTime = endTime
        session.duration = max(0, duration)
        session.tips = Double(tips) ?? 0
        session.netProfitLoss = netPL
        session.netProfitLossBase = netPLBase
        session.handsCount = Int32(handsOverride) ?? 0
        session.notes = notes.isEmpty ? nil : notes
        try? viewContext.save()
    }
}
