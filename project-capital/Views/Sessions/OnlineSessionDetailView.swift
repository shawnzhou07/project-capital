import SwiftUI
import CoreData
import Combine
import UIKit

struct OnlineSessionDetailView: View {
    @ObservedObject var session: OnlineCash
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("baseCurrency") private var baseCurrency = "CAD"
    @EnvironmentObject var coordinator: ActiveSessionCoordinator

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Platform.name, ascending: true)],
        animation: .default
    ) private var platforms: FetchedResults<Platform>

    @State private var showDeleteAlert = false
    @State private var showVerifyAlert = false
    @State private var showTimeAlert = false
    @State private var showZeroDurationAlert = false
    @State private var showBalanceDiscrepancy = false
    @State private var discrepancyResolved: Bool = false
    @State private var discrepancyDirection: DiscrepancyDirection = .higher
    @State private var discrepancyPlatformBalance: Double = 0
    @Environment(\.dismiss) private var dismiss

    enum DiscrepancyDirection { case higher, lower }

    @State private var gameType = ""
    @State private var smallBlind = ""
    @State private var bigBlind = ""
    @State private var straddle = ""
    @State private var ante = ""
    @State private var breakTimeStr = ""
    @State private var tableSize = 6
    @State private var tables = 1
    @State private var startTime = Date()
    @State private var endTime = Date()
    @State private var prevStartTime = Date()
    @State private var prevEndTime = Date()
    @State private var balanceBefore = ""
    @State private var balanceAfter = ""
    @State private var handsOverride = ""
    @State private var notes = ""
    @State private var selectedPlatform: Platform? = nil
    @State private var showPlatformPicker = false
    @State private var loaded = false
    @State private var elapsed: TimeInterval = 0
    // Tracks whether this detail view was opened while the session was active
    @State private var isSessionActive = false
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var breakTimeMinutes: Double { Double(breakTimeStr) ?? 0 }
    var duration: Double { max(0, endTime.timeIntervalSince(startTime) / 3600.0 - breakTimeMinutes / 60.0) }
    var netPL: Double { (Double(balanceAfter) ?? 0) - (Double(balanceBefore) ?? 0) }
    var netPLBase: Double { isSameCurrency ? netPL : netPL * (selectedPlatform?.latestFXConversionRate ?? 1.0) }
    var platformCurrency: String { selectedPlatform?.displayCurrency ?? session.platformCurrency }
    var isSameCurrency: Bool { platformCurrency == baseCurrency }
    var sbDouble: Double { Double(smallBlind) ?? 0 }
    var bbDouble: Double { Double(bigBlind) ?? 0 }
    var estimatedHands: Int {
        let s = UserSettings.shared
        return Int(duration * Double(s.handsPerHourOnline) * Double(tables))
    }
    var effectiveHands: Int {
        if let manual = Int(handsOverride), manual > 0 { return manual }
        return estimatedHands
    }
    var isVerified: Bool { session.isVerified }
    var canVerify: Bool {
        selectedPlatform != nil && !gameType.isEmpty && sbDouble > 0 && bbDouble > 0 && discrepancyResolved
    }

    // Live duration text (elapsed minus break time) for the active-session duration row
    var activeDurationText: String {
        let breakHours = breakTimeMinutes / 60.0
        let netHours = max(0, elapsed / 3600.0 - breakHours)
        return AppFormatter.duration(netHours)
    }

    var body: some View {
        mainContentWithAlerts
    }

    private var mainZStack: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            // Only show the gold border for verified sessions that are fully stopped.
            // Active sessions (endTime == nil) must never show the border.
            if isVerified && session.endTime != nil {
                RoundedRectangle(cornerRadius: 0)
                    .stroke(Color.appGold.opacity(0.35), lineWidth: 2.0)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .zIndex(999)
            }

            VStack(spacing: 0) {
                Form {
                    headerSection
                    platformSection
                    gameDetailsSection
                    timingSection
                    balanceSection
                    handsSection
                    notesSection
                    if !isVerified { deleteSection }
                }
                .scrollContentBackground(.hidden)
                .background(Color.appBackground)
                .selectAllOnFocus()

                verifyBar
            }
        }
    }

    private var mainContentWithOnChange: some View {
        mainZStack
            .navigationTitle("Online Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isSessionActive {
                    // Green dot appears directly to the right of the title text.
                    // .principal placement centers the title+dot in the nav bar.
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 0) {
                            Text("Online Session")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            Circle()
                                .fill(Color(hex: "#34C759"))
                                .frame(width: 10, height: 10)
                                .padding(.leading, 6)
                        }
                    }
                    // Stop button is a separate trailing item with no dot inside it.
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Stop") { stopSession() }
                            .fontWeight(.semibold)
                            .foregroundColor(.appLoss)
                    }
                }
            }
            .onAppear {
                loadFromSession()
                // Hide the floating bar while viewing the currently active session.
                if session.isActive { coordinator.isViewingActiveSessionDetail = true }
            }
            .onDisappear {
                coordinator.isViewingActiveSessionDetail = false
            }
            .onChange(of: gameType) { _, _ in autoSave() }
            .onChange(of: smallBlind) { _, _ in autoSave() }
            .onChange(of: bigBlind) { _, _ in autoSave() }
            .onChange(of: straddle) { _, _ in autoSave() }
            .onChange(of: ante) { _, _ in autoSave() }
            .onChange(of: breakTimeStr) { _, _ in autoSave() }
            .onChange(of: tableSize) { _, _ in autoSave() }
            .onChange(of: tables) { _, _ in autoSave() }
            .onChange(of: balanceBefore) { _, _ in autoSave() }
            .onChange(of: balanceAfter) { _, _ in autoSave() }
    }

    private var mainContentWithMoreOnChange: some View {
        mainContentWithOnChange
            .onChange(of: handsOverride) { _, _ in autoSave() }
            .onChange(of: notes) { _, _ in autoSave() }
            .onChange(of: selectedPlatform) { _, _ in autoSave() }
            .onChange(of: startTime) { oldVal, newVal in
                if oldVal.timeIntervalSince(newVal) > 20 * 3600 {
                    startTime = Calendar.current.date(byAdding: .day, value: 1, to: newVal) ?? newVal
                    return
                }
                if endTime <= startTime { showTimeAlert = true; startTime = prevStartTime }
                else { prevStartTime = startTime; autoSave() }
            }
            .onChange(of: endTime) { oldVal, newVal in
                guard !isSessionActive else { return }
                if oldVal.timeIntervalSince(newVal) > 20 * 3600 {
                    endTime = Calendar.current.date(byAdding: .day, value: 1, to: newVal) ?? newVal
                    return
                }
                if endTime <= startTime { showTimeAlert = true; endTime = prevEndTime }
                else { prevEndTime = endTime; autoSave() }
            }
    }

    private var mainContentWithAlerts: some View {
        mainContentWithMoreOnChange
            .alert("Invalid Time Range", isPresented: $showTimeAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("End time must be after start time.")
            }
            .alert("Invalid Session Duration", isPresented: $showZeroDurationAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your session duration is zero or negative. Please correct your start time, end time, or break time before saving.")
            }
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
                Button("Verify") { tryVerifySession() }
                    .foregroundStyle(Color.appGold)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Verify this session? Balance Before and Balance After will be permanently locked and cannot be changed.")
            }
            .alert("Balance Discrepancy", isPresented: $showBalanceDiscrepancy) {
                if discrepancyDirection == .higher {
                    Button("Add Deposit") {
                        autoSave()
                        if let platform = selectedPlatform {
                            coordinator.platformIDForDeposit = platform.objectID
                        }
                        coordinator.selectedTab = 2
                        dismiss()
                    }
                    Button("Log Adjustment") {
                        autoSave()
                        if let platform = selectedPlatform {
                            coordinator.adjustmentPlatformID = platform.objectID
                        }
                        coordinator.selectedTab = 3
                        dismiss()
                    }
                } else {
                    Button("Record Withdrawal") {
                        autoSave()
                        if let platform = selectedPlatform {
                            coordinator.platformIDForWithdrawal = platform.objectID
                        }
                        coordinator.selectedTab = 2
                        dismiss()
                    }
                    Button("Log Adjustment") {
                        autoSave()
                        if let platform = selectedPlatform {
                            coordinator.adjustmentPlatformID = platform.objectID
                        }
                        coordinator.selectedTab = 3
                        dismiss()
                    }
                }
                Button("OK", role: .cancel) {
                    discrepancyResolved = true
                }
            } message: {
                Text(discrepancyAlertMessage)
            }
            .sheet(isPresented: $showPlatformPicker) {
                PlatformPickerSheet(platforms: Array(platforms), selected: $selectedPlatform) {
                    showPlatformPicker = false
                }
            }
    }

    // MARK: - Bottom Bar

    var verifyBar: some View {
        Group {
            if isSessionActive {
                // Session is currently running — no verify bar shown
                EmptyView()
            } else if isVerified {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill").foregroundColor(.appGold).font(.subheadline)
                    Text("Verified").font(.subheadline).fontWeight(.medium).foregroundColor(.appGold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.appBackground)
            } else {
                let isStopped = session.endTime != nil
                let buttonOpacity: Double = !isStopped ? 0.4 : (canVerify ? 1.0 : 0.7)
                let isTappable = isStopped && canVerify
                Button {
                    if isTappable { showVerifyAlert = true }
                } label: {
                    Text("Verify Session")
                        .font(.headline).fontWeight(.semibold)
                        .foregroundColor(isTappable ? .black : .appGold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isTappable ? Color.appGold : Color.clear)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appGold, lineWidth: isTappable ? 0 : 1.5))
                        .cornerRadius(12)
                        .opacity(buttonOpacity)
                }
                .disabled(!isTappable)
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
                HStack(spacing: 8) {
                    if isVerified {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.appGold)
                            .shadow(color: Color.appGold.opacity(0.6), radius: 6, x: 0, y: 0)
                    }
                    Text(AppFormatter.currencySigned(session.netProfitLossBase))
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(session.netProfitLossBase.profitColor)
                        .shadow(color: session.netProfitLossBase.profitColor.opacity(isVerified ? 0.5 : 0), radius: 8, x: 0, y: 0)
                }
                HStack(spacing: 16) {
                    Label(AppFormatter.duration(session.computedDuration), systemImage: "clock")
                    Label(AppFormatter.handsCount(session.effectiveHands) + " hands", systemImage: "suit.spade")
                }
                .font(.subheadline).foregroundColor(.appSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .listRowBackground(Color.appSurface)
    }

    // MARK: - Platform

    var platformSection: some View {
        Section {
            Button { showPlatformPicker = true } label: {
                HStack {
                    Text("Platform").foregroundColor(.appPrimary)
                    Spacer()
                    Text(selectedPlatform?.displayName ?? "—").foregroundColor(.appGold)
                    Text("·").foregroundColor(.appSecondary)
                    Text(platformCurrency).foregroundColor(.appSecondary)
                    Image(systemName: "chevron.right").font(.caption).foregroundColor(.appSecondary)
                }
            }
            .listRowBackground(Color.appSurface)
        } header: {
            Text("Platform").foregroundColor(.appGold).textCase(nil)
        }
    }

    // MARK: - Game Details

    var gameDetailsSection: some View {
        Section {
            Picker("Game Type", selection: $gameType) {
                ForEach(gameTypes, id: \.self) { Text($0) }
            }
            .foregroundColor(.appPrimary)
            .listRowBackground(Color.appSurface)

            HStack(spacing: 12) {
                blindField(label: "SB", text: $smallBlind)
                blindField(label: "BB", text: $bigBlind)
                blindField(label: "STR (opt.)", text: $straddle)
                blindField(label: "Ante (opt.)", text: $ante)
            }
            .listRowBackground(Color.appSurface)

            Stepper("Table Size: \(tableSize)", value: $tableSize, in: 2...10)
                .foregroundColor(.appPrimary).listRowBackground(Color.appSurface)

            Stepper("Tables: \(tables)", value: $tables, in: 1...10)
                .foregroundColor(.appPrimary).listRowBackground(Color.appSurface)
        } header: {
            Text("Game Details").foregroundColor(.appGold).textCase(nil)
        }
    }

    @ViewBuilder
    func blindField(label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption2).foregroundColor(.appSecondary)
            CurrencyInputField(text: text, width: nil, textAlignment: .center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.appSurface2)
                .cornerRadius(6)
        }
    }

    // MARK: - Timing

    var timingSection: some View {
        Section {
            DatePicker("Start", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                .foregroundColor(.appPrimary).tint(.appGold)
                .listRowBackground(Color.appSurface)
            if !isSessionActive {
                DatePicker("End", selection: $endTime, displayedComponents: [.date, .hourAndMinute])
                    .foregroundColor(.appPrimary).tint(.appGold)
                    .listRowBackground(Color.appSurface)
            }
            HStack {
                Text("Break (min)").foregroundColor(.appPrimary)
                Spacer()
                CurrencyInputField(text: $breakTimeStr, width: 80, maxDecimalPlaces: 0)
            }
            .listRowBackground(Color.appSurface)
            HStack {
                Text("Duration").foregroundColor(.appPrimary)
                Spacer()
                if isSessionActive {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: "#34C759"))
                            .frame(width: 8, height: 8)
                        Text(activeDurationText)
                            .foregroundColor(.appSecondary)
                            .monospacedDigit()
                    }
                    .onReceive(timer) { _ in elapsed += 1 }
                } else {
                    Text(AppFormatter.duration(duration)).foregroundColor(.appSecondary)
                }
            }
            .listRowBackground(Color.appSurface)
        } header: {
            Text("Timing").foregroundColor(.appGold).textCase(nil)
        }
    }

    // MARK: - Balance

    var balanceSection: some View {
        Section {
            if isVerified {
                lockedRow(label: "Balance Before", value: "\(platformCurrency) \(String(format: "%.2f", session.balanceBefore))")
            } else {
                HStack {
                    Text("Balance Before").foregroundColor(.appPrimary)
                    Spacer()
                    Text(platformCurrency).font(.caption).foregroundColor(.appSecondary)
                    CurrencyInputField(text: $balanceBefore, width: 100)
                }
                .listRowBackground(Color.appSurface)
            }

            if isVerified {
                lockedRow(label: "Balance After", value: "\(platformCurrency) \(String(format: "%.2f", session.balanceAfter))")
            } else {
                HStack {
                    Text("Balance After").foregroundColor(.appPrimary)
                    Spacer()
                    Text(platformCurrency).font(.caption).foregroundColor(.appSecondary)
                    CurrencyInputField(text: $balanceAfter, width: 100)
                }
                .listRowBackground(Color.appSurface)
            }

            // Net Result row — gold lock + glow when verified
            HStack {
                Text("Net Result").foregroundColor(.appPrimary)
                Spacer()
                HStack(spacing: 4) {
                    if isVerified {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundColor(.appGold)
                            .shadow(color: Color.appGold.opacity(0.8), radius: 4, x: 0, y: 0)
                    }
                    VStack(alignment: .trailing, spacing: 2) {
                        let netToShow = isVerified ? session.netProfitLoss : netPL
                        let netBaseToShow = isVerified ? session.netProfitLossBase : netPLBase
                        Text(AppFormatter.currencySigned(netToShow, code: platformCurrency))
                            .fontWeight(.semibold)
                            .foregroundColor(netToShow.profitColor)
                            .shadow(
                                color: isVerified ? netToShow.profitColor.opacity(0.8) : .clear,
                                radius: 8, x: 0, y: 0
                            )
                        if !isSameCurrency {
                            Text(AppFormatter.currencySigned(netBaseToShow, code: baseCurrency))
                                .font(.caption)
                                .foregroundColor(netBaseToShow.profitColor)
                                .shadow(
                                    color: isVerified ? netBaseToShow.profitColor.opacity(0.8) : .clear,
                                    radius: 8, x: 0, y: 0
                                )
                        }
                    }
                }
            }
            .listRowBackground(Color.appSurface)
        } header: {
            Text("Balance").foregroundColor(.appGold).textCase(nil)
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
                    .foregroundColor(.white).frame(width: 140)
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
        Button { triggerLockHaptic() } label: {
            HStack {
                Text(label).foregroundColor(.appPrimary)
                Spacer()
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundColor(.appGold)
                    .shadow(color: Color(hex: "#C9B47A"), radius: 6, x: 0, y: 0)
                Text(value)
                    .foregroundColor(.appPrimary)
                    .shadow(color: Color(hex: "#C9B47A"), radius: 6, x: 0, y: 0)
            }
        }
        .listRowBackground(Color.appSurface)
    }

    func triggerLockHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.impactOccurred()
    }

    var discrepancyAlertMessage: String {
        let currentBal = AppFormatter.currency(discrepancyPlatformBalance, code: platformCurrency)
        let expectedBal = AppFormatter.currency(session.balanceAfter, code: platformCurrency)
        if discrepancyDirection == .higher {
            return "The platform now shows \(currentBal), but this session recorded \(expectedBal) as the balance after. It appears funds were added. Would you like to record a deposit or log an adjustment?"
        } else {
            return "The platform now shows \(currentBal), but this session recorded \(expectedBal) as the balance after. It appears funds are missing. Would you like to record a withdrawal or log an adjustment?"
        }
    }

    func checkDiscrepancy() {
        guard !session.isVerified, let platform = selectedPlatform else {
            discrepancyResolved = true
            return
        }
        let currentBal = platform.currentBalance
        let expectedBal = session.balanceAfter
        guard abs(currentBal - expectedBal) > 0.01 else {
            discrepancyResolved = true
            return
        }
        discrepancyPlatformBalance = currentBal
        discrepancyDirection = currentBal > expectedBal ? .higher : .lower
        showBalanceDiscrepancy = true
    }

    func tryVerifySession() {
        guard duration > 0 else { showZeroDurationAlert = true; return }
        verifySession()
    }

    func verifySession() {
        session.isVerified = true
        selectedPlatform?.currentBalance = session.balanceAfter
        autoSave()
    }

    /// Stop the active session: record end time and transition to stopped state.
    func stopSession() {
        endTime = Date()
        session.endTime = endTime
        session.breakTime = breakTimeMinutes
        session.duration = max(0, endTime.timeIntervalSince(startTime) / 3600.0 - breakTimeMinutes / 60.0)
        isSessionActive = false
        prevEndTime = endTime
        try? viewContext.save()
    }

    func loadFromSession() {
        guard !loaded else { return }
        loaded = true
        // Capture active state before setting up other fields
        isSessionActive = session.isActive
        gameType = session.gameType ?? "No Limit Hold'em"

        if session.smallBlind > 0 || session.bigBlind > 0 {
            smallBlind = AppFormatter.blindValue(session.smallBlind)
            bigBlind = AppFormatter.blindValue(session.bigBlind)
            straddle = session.straddle > 0 ? AppFormatter.blindValue(session.straddle) : ""
            ante = session.ante > 0 ? AppFormatter.blindValue(session.ante) : ""
        } else if let blindsStr = session.blinds, !blindsStr.isEmpty {
            let parts = blindsStr.split(separator: "/")
            if parts.count >= 2 {
                smallBlind = String(parts[0]).trimmingCharacters(in: .whitespaces)
                bigBlind = String(parts[1]).trimmingCharacters(in: .whitespaces)
            }
        }
        breakTimeStr = session.breakTime > 0 ? String(Int(session.breakTime)) : ""
        tableSize = Int(session.tableSize)
        tables = Int(session.tables)
        startTime = session.startTime ?? Date()
        // For active sessions, use a placeholder endTime that is NOT written back to Core Data
        endTime = session.isActive ? Date() : (session.endTime ?? Date())
        prevStartTime = startTime
        prevEndTime = endTime
        balanceBefore = session.balanceBefore == 0 ? "" : String(format: "%.2f", session.balanceBefore)
        balanceAfter = session.balanceAfter == 0 ? "" : String(format: "%.2f", session.balanceAfter)
        handsOverride = session.handsCount > 0 ? "\(session.handsCount)" : ""
        notes = session.notes ?? ""
        selectedPlatform = session.platform
        if session.isActive, let start = session.startTime {
            elapsed = Date().timeIntervalSince(start)
        }
        // Only check balance discrepancy for completed (stopped) sessions
        if !session.isActive {
            checkDiscrepancy()
        } else {
            discrepancyResolved = true
        }
    }

    func autoSave() {
        guard loaded else { return }
        session.gameType = gameType
        session.smallBlind = sbDouble
        session.bigBlind = bbDouble
        session.straddle = Double(straddle) ?? 0
        session.ante = Double(ante) ?? 0
        session.blinds = "\(AppFormatter.blindValue(sbDouble))/\(AppFormatter.blindValue(bbDouble))"
        session.tableSize = Int16(tableSize)
        session.tables = Int16(tables)
        session.breakTime = breakTimeMinutes
        session.startTime = startTime
        // Only write endTime and duration once the session is stopped
        if !isSessionActive {
            session.endTime = endTime
            session.duration = duration
        }
        if !isVerified {
            session.balanceBefore = Double(balanceBefore) ?? 0
            session.balanceAfter = Double(balanceAfter) ?? 0
            selectedPlatform?.currentBalance = Double(balanceAfter) ?? 0
        }
        session.exchangeRateToBase = selectedPlatform?.latestFXConversionRate ?? 1.0
        session.netProfitLoss = netPL
        session.netProfitLossBase = netPLBase
        session.handsCount = Int32(handsOverride) ?? 0
        session.notes = notes.isEmpty ? nil : notes
        session.platform = selectedPlatform
        try? viewContext.save()
    }
}
