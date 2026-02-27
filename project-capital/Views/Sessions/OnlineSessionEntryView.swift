import SwiftUI
import CoreData
import Combine

struct OnlineSessionEntryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var coordinator: ActiveSessionCoordinator
    @AppStorage("baseCurrency") private var baseCurrency = "CAD"

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Platform.name, ascending: true)],
        animation: .default
    ) private var platforms: FetchedResults<Platform>

    var existingSession: OnlineCash? = nil

    enum EntryState { case preStart, active, stopped }

    @State private var entryState: EntryState = .preStart
    @State private var coreDataSession: OnlineCash? = nil

    @State private var startTime = Date()
    @State private var endTime = Date()

    @State private var selectedPlatform: Platform? = nil
    @State private var gameType = "No Limit Hold'em"
    @State private var smallBlind = ""
    @State private var bigBlind = ""
    @State private var straddle = ""
    @State private var ante = ""
    @State private var breakTimeStr = ""
    @State private var tableSize = 6
    @State private var tables = 1
    @State private var balanceBefore = ""
    @State private var balanceAfter = ""
    @State private var handsOverride = ""
    @State private var notes = ""

    @State private var showDiscardAlert = false
    @State private var showRequiredFieldsAlert = false
    @State private var showPlatformPicker = false
    @State private var showZeroDurationAlert = false
    @State private var showNoPlatformAlert = false
    @State private var tick = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // Balance discrepancy
    @State private var showBalanceDiscrepancy = false
    @State private var discrepancyEnteredBalance: Double = 0
    @State private var discrepancyRecordedBalance: Double = 0
    @State private var discrepancyDirection: DiscrepancyDirection = .higher

    enum DiscrepancyDirection { case higher, lower }

    var platformCurrency: String { selectedPlatform?.displayCurrency ?? "USD" }
    var isSameCurrency: Bool { platformCurrency == baseCurrency }
    var sbDouble: Double { Double(smallBlind) ?? 0 }
    var bbDouble: Double { Double(bigBlind) ?? 0 }
    var breakTimeMinutes: Double { Double(breakTimeStr) ?? 0 }

    var netResult: Double {
        (Double(balanceAfter) ?? 0) - (Double(balanceBefore) ?? 0)
    }

    var netResultBase: Double {
        isSameCurrency ? netResult : netResult * (selectedPlatform?.latestFXConversionRate ?? 1.0)
    }

    var sessionDurationHours: Double {
        switch entryState {
        case .preStart: return 0
        case .active: return max(0, tick.timeIntervalSince(startTime) / 3600.0)
        case .stopped: return max(0, endTime.timeIntervalSince(startTime) / 3600.0 - breakTimeMinutes / 60.0)
        }
    }

    var estimatedHands: Int {
        Int(sessionDurationHours * Double(UserSettings.shared.handsPerHourOnline) * Double(tables))
    }

    var elapsedText: String {
        let totalMinutes = Int(sessionDurationHours * 60)
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        return "\(h)h \(m)m"
    }

    var isValidForSave: Bool { selectedPlatform != nil && sbDouble > 0 && bbDouble > 0 }

    var hasData: Bool {
        selectedPlatform != nil || sbDouble > 0 || bbDouble > 0 || !balanceBefore.isEmpty || !balanceAfter.isEmpty || !notes.isEmpty
    }

    var body: some View {
        configuredForm
            .alert("Discard session?", isPresented: $showDiscardAlert) {
                Button("Discard", role: .destructive) { discardSession() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All entered data will be lost.")
            }
            .alert("Required Fields Missing", isPresented: $showRequiredFieldsAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please select a platform and fill in SB and BB before saving.")
            }
            .alert("Invalid Session Duration", isPresented: $showZeroDurationAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your session duration is zero or negative. Please correct your start time, end time, or break time before saving.")
            }
            .alert("Platform Required", isPresented: $showNoPlatformAlert) {
                Button("Go to Platforms") {
                    coordinator.shouldOpenAddPlatform = true
                    coordinator.selectedTab = 2
                    coordinator.dismissForm()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You need to select a platform before starting an online session. Would you like to go to Platforms to create one?")
            }
            .alert(discrepancyAlertTitle, isPresented: $showBalanceDiscrepancy) {
                if discrepancyDirection == .higher {
                    Button("Add Deposit") {
                        saveDraftIfNeeded()
                        if let platform = selectedPlatform {
                            coordinator.platformIDForDeposit = platform.objectID
                        }
                        coordinator.selectedTab = 2
                        coordinator.dismissForm()
                    }
                    Button("Log Adjustment") {
                        saveDraftIfNeeded()
                        if let platform = selectedPlatform {
                            coordinator.adjustmentPlatformID = platform.objectID
                        }
                        coordinator.selectedTab = 3
                        coordinator.dismissForm()
                    }
                } else {
                    Button("Record Withdrawal") {
                        saveDraftIfNeeded()
                        if let platform = selectedPlatform {
                            coordinator.platformIDForWithdrawal = platform.objectID
                        }
                        coordinator.selectedTab = 2
                        coordinator.dismissForm()
                    }
                    Button("Log Adjustment") {
                        saveDraftIfNeeded()
                        if let platform = selectedPlatform {
                            coordinator.adjustmentPlatformID = platform.objectID
                        }
                        coordinator.selectedTab = 3
                        coordinator.dismissForm()
                    }
                }
                Button("OK", role: .cancel) {
                    let recorded = selectedPlatform?.currentBalance ?? 0
                    balanceBefore = recorded == 0 ? "" : String(format: "%.2f", recorded)
                }
            } message: {
                Text(discrepancyAlertMessage)
            }
            .onAppear {
                if let session = existingSession {
                    loadFromExisting(session)
                } else if selectedPlatform == nil, let first = platforms.first {
                    selectedPlatform = first
                    autoFillBalanceBefore(from: first)
                }
            }
            .onChange(of: selectedPlatform) { _, newPlatform in
                if let p = newPlatform, entryState == .preStart {
                    autoFillBalanceBefore(from: p)
                }
            }
            .onReceive(timer) { t in if entryState == .active { tick = t } }
    }

    func autoFillBalanceBefore(from platform: Platform) {
        let bal = platform.currentBalance
        balanceBefore = bal == 0 ? "" : String(format: "%.2f", bal)
    }

    var discrepancyAlertTitle: String { "Balance Discrepancy" }

    var discrepancyAlertMessage: String {
        let entered = AppFormatter.currency(discrepancyEnteredBalance, code: platformCurrency)
        let recorded = AppFormatter.currency(discrepancyRecordedBalance, code: platformCurrency)
        if discrepancyDirection == .higher {
            return "You entered \(entered) but the platform balance is \(recorded). It appears funds are missing from the record. Would you like to add a deposit or log an adjustment?"
        } else {
            return "You entered \(entered) but the platform balance is \(recorded). It appears there are extra funds in the record. Would you like to record a withdrawal or log an adjustment?"
        }
    }

    private var configuredForm: some View {
        baseForm
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { leadingButton }
                ToolbarItem(placement: .navigationBarTrailing) { trailingToolbarButton }
            }
    }

    private var baseForm: some View {
        Form {
            platformSection
            sessionDetailsSection
            timingSection
            balanceSection
            handsSection
            notesSection
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .selectAllOnFocus()
        .navigationTitle("Online Session")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }

    @ViewBuilder
    private var trailingToolbarButton: some View {
        if entryState == .preStart {
            Button("Start") { handleStart() }
                .fontWeight(.semibold).foregroundColor(.appGold)
        } else if entryState == .active {
            Button("Stop") { handleStop() }
                .fontWeight(.semibold).foregroundColor(.appLoss)
        } else if entryState == .stopped {
            Button("Save") {
                if isValidForSave { trySaveFinal() } else { showRequiredFieldsAlert = true }
            }
            .fontWeight(.semibold).foregroundColor(.appGold)
        }
    }

    @ViewBuilder
    private var leadingButton: some View {
        switch entryState {
        case .preStart:
            Button {
                if hasData { showDiscardAlert = true } else { coordinator.dismissForm() }
            } label: {
                Image(systemName: "xmark").foregroundColor(.appSecondary)
            }
        case .active:
            Button { coordinator.dismissForm() } label: {
                Image(systemName: "chevron.left").foregroundColor(.appGold)
            }
        case .stopped:
            Button { coordinator.dismissForm() } label: {
                Image(systemName: "chevron.left").foregroundColor(.appGold)
            }
        }
    }

    // MARK: - Form Sections

    var platformSection: some View {
        Section {
            Button { showPlatformPicker = true } label: {
                HStack {
                    Text("Platform").foregroundColor(.appPrimary)
                    Spacer()
                    Text(selectedPlatform?.displayName ?? "Select")
                        .foregroundColor(selectedPlatform == nil ? .appSecondary : .appGold)
                    if selectedPlatform != nil {
                        Text("·").foregroundColor(.appSecondary)
                        Text(platformCurrency).foregroundColor(.appSecondary)
                    }
                    Image(systemName: "chevron.right").font(.caption).foregroundColor(.appSecondary)
                }
            }
            .listRowBackground(Color.appSurface)
        } header: {
            Text("Platform").foregroundColor(.appGold).textCase(nil)
        }
        .sheet(isPresented: $showPlatformPicker) {
            PlatformPickerSheet(platforms: Array(platforms), selected: $selectedPlatform, onCreatePlatform: {
                showPlatformPicker = false
                coordinator.shouldOpenAddPlatform = true
                coordinator.selectedTab = 2
                coordinator.dismissForm()
            }) {
                autoSaveIfActive()
                showPlatformPicker = false
            }
        }
    }

    var sessionDetailsSection: some View {
        Section {
            Picker("Game Type", selection: $gameType) {
                ForEach(gameTypes, id: \.self) { Text($0) }
            }
            .foregroundColor(.appPrimary)
            .listRowBackground(Color.appSurface)
            .onChange(of: gameType) { _, _ in autoSaveIfActive() }

            HStack(spacing: 12) {
                blindField(label: "SB", text: $smallBlind)
                blindField(label: "BB", text: $bigBlind)
                blindField(label: "STR (opt.)", text: $straddle)
                blindField(label: "Ante (opt.)", text: $ante)
            }
            .listRowBackground(Color.appSurface)
            .onChange(of: smallBlind) { _, _ in autoSaveIfActive() }
            .onChange(of: bigBlind) { _, _ in autoSaveIfActive() }
            .onChange(of: straddle) { _, _ in autoSaveIfActive() }
            .onChange(of: ante) { _, _ in autoSaveIfActive() }

            Stepper("Table Size: \(tableSize)", value: $tableSize, in: 2...10)
                .foregroundColor(.appPrimary)
                .listRowBackground(Color.appSurface)
                .onChange(of: tableSize) { _, _ in autoSaveIfActive() }

            Stepper("Tables: \(tables)", value: $tables, in: 1...10)
                .foregroundColor(.appPrimary)
                .listRowBackground(Color.appSurface)
                .onChange(of: tables) { _, _ in autoSaveIfActive() }
        } header: {
            Text("Game Details").foregroundColor(.appGold).textCase(nil)
        }
    }

    @ViewBuilder
    func blindField(label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.appSecondary)
            CurrencyInputField(text: text, width: nil, textAlignment: .center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.appSurface2)
                .cornerRadius(6)
        }
    }

    var timingSection: some View {
        Section {
            DatePicker("Start Time", selection: $startTime)
                .foregroundColor(.appPrimary).tint(.appGold)
                .listRowBackground(Color.appSurface)
                .onChange(of: startTime) { _, _ in autoSaveIfActive() }

            DatePicker("End Time", selection: $endTime)
                .foregroundColor(.appPrimary).tint(.appGold)
                .listRowBackground(Color.appSurface)
                .disabled(entryState != .stopped)
                .opacity(entryState == .stopped ? 1.0 : 0.4)

            HStack {
                Text("Break (min)").foregroundColor(.appPrimary)
                Spacer()
                CurrencyInputField(text: $breakTimeStr, width: 80, maxDecimalPlaces: 0)
                    .onChange(of: breakTimeStr) { _, _ in autoSaveIfActive() }
            }
            .listRowBackground(Color.appSurface)

            HStack {
                Text("Duration").foregroundColor(.appPrimary)
                Spacer()
                if entryState == .active {
                    HStack(spacing: 6) {
                        Circle().fill(Color(hex: "#34C759")).frame(width: 6, height: 6)
                        Text(elapsedText).foregroundColor(.appSecondary).fontWeight(.medium).monospacedDigit()
                    }
                } else if entryState == .stopped {
                    Text(AppFormatter.duration(sessionDurationHours)).foregroundColor(.appSecondary)
                } else {
                    Text("—").foregroundColor(.appSecondary)
                }
            }
            .listRowBackground(Color.appSurface)
        } header: {
            Text("Timing").foregroundColor(.appGold).textCase(nil)
        }
    }

    var balanceSection: some View {
        Section {
            HStack {
                Text("Balance Before").foregroundColor(.appPrimary)
                Spacer()
                Text(platformCurrency).font(.caption).foregroundColor(.appSecondary)
                CurrencyInputField(
                    text: $balanceBefore,
                    width: 100,
                    onFocusChange: { focused in
                        if !focused { checkBalanceDiscrepancy() }
                        autoSaveIfActive()
                    }
                )
            }
            .listRowBackground(Color.appSurface)

            HStack {
                Text("Balance After").foregroundColor(.appPrimary)
                Spacer()
                Text(platformCurrency).font(.caption).foregroundColor(.appSecondary)
                CurrencyInputField(text: $balanceAfter, width: 100)
                    .onChange(of: balanceAfter) { _, _ in autoSaveIfActive() }
            }
            .listRowBackground(Color.appSurface)

            HStack {
                Text("Net Result").foregroundColor(.appPrimary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(AppFormatter.currencySigned(netResult, code: platformCurrency))
                        .fontWeight(.semibold).foregroundColor(netResult.profitColor)
                    if !isSameCurrency {
                        Text(AppFormatter.currencySigned(netResultBase, code: baseCurrency))
                            .font(.caption).foregroundColor(netResultBase.profitColor)
                    }
                }
            }
            .listRowBackground(Color.appSurface)
        } header: {
            Text("Balance").foregroundColor(.appGold).textCase(nil)
        }
    }

    var handsSection: some View {
        Section {
            HStack {
                Text("Hands Played").foregroundColor(.appPrimary)
                Spacer()
                TextField("Auto (\(estimatedHands) est.)", text: $handsOverride)
                    .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                    .foregroundColor(.white).frame(width: 140)
                    .onChange(of: handsOverride) { _, _ in autoSaveIfActive() }
            }
            .listRowBackground(Color.appSurface)
        } header: {
            Text("Hands").foregroundColor(.appGold).textCase(nil)
        }
    }

    var notesSection: some View {
        Section {
            TextEditor(text: $notes)
                .frame(minHeight: 80).foregroundColor(.appPrimary)
                .scrollContentBackground(.hidden).background(Color.appSurface)
                .listRowBackground(Color.appSurface)
                .onChange(of: notes) { _, _ in autoSaveIfActive() }
        } header: {
            Text("Notes").foregroundColor(.appGold).textCase(nil)
        }
    }

    // MARK: - Actions

    func saveDraftIfNeeded() {
        guard coreDataSession == nil, let platform = selectedPlatform else { return }
        let session = OnlineCash(context: viewContext)
        session.id = UUID()
        session.platform = platform
        session.gameType = gameType
        session.smallBlind = sbDouble
        session.bigBlind = bbDouble
        session.straddle = Double(straddle) ?? 0
        session.ante = Double(ante) ?? 0
        session.blinds = "\(AppFormatter.blindValue(sbDouble))/\(AppFormatter.blindValue(bbDouble))"
        session.tableSize = Int16(tableSize)
        session.tables = Int16(tables)
        session.balanceBefore = Double(balanceBefore) ?? 0
        session.balanceAfter = Double(balanceAfter) ?? 0
        session.exchangeRateToBase = platform.latestFXConversionRate
        session.notes = notes.isEmpty ? nil : notes
        try? viewContext.save()
        coreDataSession = session
    }

    func handleStart() {
        guard let platform = selectedPlatform else { showNoPlatformAlert = true; return }
        startTime = Date()
        let session = OnlineCash(context: viewContext)
        session.id = UUID()
        session.platform = platform
        session.gameType = gameType
        session.smallBlind = sbDouble
        session.bigBlind = bbDouble
        session.straddle = Double(straddle) ?? 0
        session.ante = Double(ante) ?? 0
        session.blinds = "\(AppFormatter.blindValue(sbDouble))/\(AppFormatter.blindValue(bbDouble))"
        session.tableSize = Int16(tableSize)
        session.tables = Int16(tables)
        session.balanceBefore = Double(balanceBefore) ?? 0
        session.balanceAfter = Double(balanceAfter) ?? 0
        session.exchangeRateToBase = platform.latestFXConversionRate
        session.notes = notes.isEmpty ? nil : notes
        session.startTime = startTime
        do {
            try viewContext.save()
            coreDataSession = session
            entryState = .active
        } catch { print("Start error: \(error)") }
    }

    func handleStop() {
        guard let session = coreDataSession else { return }
        endTime = Date()
        session.endTime = endTime
        session.breakTime = breakTimeMinutes
        session.duration = max(0, endTime.timeIntervalSince(startTime) / 3600.0 - breakTimeMinutes / 60.0)
        do {
            try viewContext.save()
            entryState = .stopped
        } catch { print("Stop error: \(error)") }
    }

    func trySaveFinal() {
        guard sessionDurationHours > 0 else { showZeroDurationAlert = true; return }
        saveFinal()
    }

    func saveFinal() {
        guard let session = coreDataSession, let platform = selectedPlatform else { return }
        session.platform = platform
        session.gameType = gameType
        session.smallBlind = sbDouble
        session.bigBlind = bbDouble
        session.straddle = Double(straddle) ?? 0
        session.ante = Double(ante) ?? 0
        session.blinds = "\(AppFormatter.blindValue(sbDouble))/\(AppFormatter.blindValue(bbDouble))"
        session.tableSize = Int16(tableSize)
        session.tables = Int16(tables)
        session.startTime = startTime
        session.endTime = endTime
        session.breakTime = breakTimeMinutes
        session.duration = sessionDurationHours
        session.balanceBefore = Double(balanceBefore) ?? 0
        session.balanceAfter = Double(balanceAfter) ?? 0
        session.netProfitLoss = netResult
        session.exchangeRateToBase = platform.latestFXConversionRate
        session.netProfitLossBase = netResultBase
        session.handsCount = Int32(handsOverride) ?? 0
        session.notes = notes.isEmpty ? nil : notes
        platform.currentBalance = Double(balanceAfter) ?? platform.currentBalance
        do {
            try viewContext.save()
            coordinator.dismissForm()
        } catch { print("Save error: \(error)") }
    }

    func discardSession() {
        if let session = coreDataSession {
            viewContext.delete(session)
            try? viewContext.save()
        }
        coordinator.dismissForm()
    }

    func autoSaveIfActive() {
        guard entryState == .active, let session = coreDataSession, let platform = selectedPlatform else { return }
        session.platform = platform
        session.gameType = gameType
        session.smallBlind = sbDouble
        session.bigBlind = bbDouble
        session.straddle = Double(straddle) ?? 0
        session.ante = Double(ante) ?? 0
        session.blinds = "\(AppFormatter.blindValue(sbDouble))/\(AppFormatter.blindValue(bbDouble))"
        session.tableSize = Int16(tableSize)
        session.tables = Int16(tables)
        session.balanceBefore = Double(balanceBefore) ?? 0
        session.balanceAfter = Double(balanceAfter) ?? 0
        session.exchangeRateToBase = platform.latestFXConversionRate
        session.notes = notes.isEmpty ? nil : notes
        try? viewContext.save()
    }

    func checkBalanceDiscrepancy() {
        guard let platform = selectedPlatform else { return }
        let entered = Double(balanceBefore) ?? 0
        let recorded = platform.currentBalance
        guard abs(entered - recorded) > 0.01 else { return }

        discrepancyEnteredBalance = entered
        discrepancyRecordedBalance = recorded
        discrepancyDirection = entered > recorded ? .higher : .lower
        showBalanceDiscrepancy = true
    }

    func loadFromExisting(_ session: OnlineCash) {
        coreDataSession = session
        selectedPlatform = session.platform
        gameType = session.gameType ?? "No Limit Hold'em"
        tableSize = Int(session.tableSize)
        tables = Int(session.tables)
        balanceBefore = session.balanceBefore > 0 ? String(session.balanceBefore) : ""
        balanceAfter = session.balanceAfter > 0 ? String(session.balanceAfter) : ""
        handsOverride = session.handsCount > 0 ? String(session.handsCount) : ""
        notes = session.notes ?? ""
        startTime = session.startTime ?? Date()

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
        entryState = .active
    }
}
