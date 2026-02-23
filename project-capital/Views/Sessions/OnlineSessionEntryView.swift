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

    // Optional: passed when re-expanding from floating bar
    var existingSession: OnlineCash? = nil

    enum EntryState { case preStart, active, stopped }

    @State private var entryState: EntryState = .preStart
    @State private var coreDataSession: OnlineCash? = nil

    // Timing state vars (always editable)
    @State private var startTime = Date()
    @State private var endTime = Date()

    // Form fields
    @State private var selectedPlatform: Platform? = nil
    @State private var gameType = "No Limit Hold'em"
    @State private var blinds = ""
    @State private var tableSize = 6
    @State private var tables = 1
    @State private var balanceBefore = ""
    @State private var balanceAfter = ""
    @State private var exchangeRate = "1.0000"
    @State private var handsOverride = ""
    @State private var notes = ""

    @State private var showDiscardAlert = false
    @State private var showRequiredFieldsAlert = false
    @State private var showPlatformPicker = false
    @State private var tick = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // Balance discrepancy
    @FocusState private var balanceBeforeFocused: Bool
    @State private var showBalanceDiscrepancy = false
    @State private var discrepancyEnteredBalance: Double = 0
    @State private var discrepancyRecordedBalance: Double = 0
    @State private var showDepositForDiscrepancy = false

    // MARK: - Computed

    var platformCurrency: String { selectedPlatform?.displayCurrency ?? "USD" }
    var isSameCurrency: Bool { platformCurrency == baseCurrency }

    var netResult: Double {
        (Double(balanceAfter) ?? 0) - (Double(balanceBefore) ?? 0)
    }

    var netResultBase: Double {
        netResult * (Double(exchangeRate) ?? 1.0)
    }

    var sessionDurationHours: Double {
        switch entryState {
        case .preStart: return 0
        case .active: return max(0, tick.timeIntervalSince(startTime) / 3600.0)
        case .stopped: return max(0, endTime.timeIntervalSince(startTime) / 3600.0)
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

    var isValidForSave: Bool { selectedPlatform != nil && !blinds.isEmpty }

    var hasData: Bool {
        selectedPlatform != nil || !blinds.isEmpty || !balanceBefore.isEmpty || !balanceAfter.isEmpty || !notes.isEmpty
    }

    // MARK: - Body

    var body: some View {
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
        .navigationTitle("Online Session")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                leadingButton
            }
            if entryState == .preStart {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Start") { handleStart() }
                        .fontWeight(.semibold)
                        .foregroundColor(.appGold)
                }
            } else if entryState == .active {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Stop") { handleStop() }
                        .fontWeight(.semibold)
                        .foregroundColor(.appLoss)
                }
            }
        }
        .alert("Discard session?", isPresented: $showDiscardAlert) {
            Button("Discard", role: .destructive) { discardSession() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All entered data will be lost.")
        }
        .alert("Required Fields Missing", isPresented: $showRequiredFieldsAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please fill in all required fields before saving your session.")
        }
        .confirmationDialog(
            "Balance Discrepancy Detected",
            isPresented: $showBalanceDiscrepancy,
            titleVisibility: .visible
        ) {
            Button("Add Deposit") { showDepositForDiscrepancy = true }
            Button("Log as Adjustment") { logDiscrepancyAsAdjustment() }
            Button("Ignore", role: .cancel) {}
        } message: {
            Text("Your entered balance (\(AppFormatter.currency(discrepancyEnteredBalance, code: platformCurrency))) does not match the recorded platform balance (\(AppFormatter.currency(discrepancyRecordedBalance, code: platformCurrency))). How would you like to resolve this?")
        }
        .sheet(isPresented: $showDepositForDiscrepancy) {
            if let platform = selectedPlatform {
                DepositFormView(platform: platform)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
        .onAppear {
            if let session = existingSession {
                loadFromExisting(session)
            } else if selectedPlatform == nil, let first = platforms.first {
                selectedPlatform = first
                syncExchangeRate()
            }
        }
        .onReceive(timer) { t in
            if entryState == .active { tick = t }
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
            Button {
                if isValidForSave { saveFinal() } else { showRequiredFieldsAlert = true }
            } label: {
                Image(systemName: "chevron.left").foregroundColor(.appGold)
            }
        }
    }

    // MARK: - Form Sections

    var platformSection: some View {
        Section {
            Button {
                showPlatformPicker = true
            } label: {
                HStack {
                    Text("Platform").foregroundColor(.appPrimary)
                    Spacer()
                    Text(selectedPlatform?.displayName ?? "Select...")
                        .foregroundColor(selectedPlatform == nil ? .appSecondary : .appGold)
                    if selectedPlatform != nil {
                        Text("·").foregroundColor(.appSecondary)
                        Text(platformCurrency).foregroundColor(.appSecondary)
                    }
                    Image(systemName: "chevron.right").font(.caption).foregroundColor(.appSecondary)
                }
            }
            .listRowBackground(Color.appSurface)

            if !isSameCurrency {
                HStack {
                    Text("Exchange Rate").foregroundColor(.appPrimary)
                    Spacer()
                    TextField("1.0000", text: $exchangeRate)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.appGold)
                        .frame(width: 100)
                        .onChange(of: exchangeRate) { _, _ in autoSaveIfActive() }
                    Text("\(platformCurrency)/\(baseCurrency)").font(.caption).foregroundColor(.appSecondary)
                }
                .listRowBackground(Color.appSurface)
            }
        } header: {
            Text("Platform").foregroundColor(.appGold).textCase(nil)
        }
        .sheet(isPresented: $showPlatformPicker) {
            PlatformPickerSheet(platforms: Array(platforms), selected: $selectedPlatform) {
                syncExchangeRate()
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

            HStack {
                Text("Blinds").foregroundColor(.appPrimary)
                Spacer()
                TextField("1/2", text: $blinds)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.appGold)
                    .onChange(of: blinds) { _, _ in autoSaveIfActive() }
            }
            .listRowBackground(Color.appSurface)

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
                Text("Duration").foregroundColor(.appPrimary)
                Spacer()
                if entryState == .active {
                    HStack(spacing: 6) {
                        Circle().fill(Color.appGold).frame(width: 6, height: 6)
                        Text(elapsedText).foregroundColor(.appGold).fontWeight(.medium).monospacedDigit()
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
                TextField("0.00", text: $balanceBefore)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.appPrimary)
                    .frame(width: 100)
                    .focused($balanceBeforeFocused)
                    .onChange(of: balanceBefore) { _, _ in autoSaveIfActive() }
            }
            .listRowBackground(Color.appSurface)

            HStack {
                Text("Balance After").foregroundColor(.appPrimary)
                Spacer()
                Text(platformCurrency).font(.caption).foregroundColor(.appSecondary)
                TextField("0.00", text: $balanceAfter)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.appPrimary)
                    .frame(width: 100)
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
        .onChange(of: balanceBeforeFocused) { _, isFocused in
            if !isFocused { checkBalanceDiscrepancy() }
        }
    }

    var handsSection: some View {
        Section {
            HStack {
                Text("Hands Played").foregroundColor(.appPrimary)
                Spacer()
                TextField("Auto (\(estimatedHands) est.)", text: $handsOverride)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.appGold)
                    .frame(width: 140)
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
                .frame(minHeight: 80)
                .foregroundColor(.appPrimary)
                .scrollContentBackground(.hidden)
                .background(Color.appSurface)
                .listRowBackground(Color.appSurface)
                .onChange(of: notes) { _, _ in autoSaveIfActive() }
        } header: {
            Text("Notes").foregroundColor(.appGold).textCase(nil)
        }
    }

    // MARK: - Actions

    func handleStart() {
        guard let platform = selectedPlatform else { return }
        startTime = Date()
        let session = OnlineCash(context: viewContext)
        session.id = UUID()
        session.platform = platform
        session.gameType = gameType
        session.blinds = blinds
        session.tableSize = Int16(tableSize)
        session.tables = Int16(tables)
        session.balanceBefore = Double(balanceBefore) ?? 0
        session.balanceAfter = Double(balanceAfter) ?? 0
        session.exchangeRateToBase = Double(exchangeRate) ?? 1.0
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
        session.duration = max(0, endTime.timeIntervalSince(startTime) / 3600.0)
        do {
            try viewContext.save()
            entryState = .stopped
        } catch { print("Stop error: \(error)") }
    }

    func saveFinal() {
        guard let session = coreDataSession, let platform = selectedPlatform else { return }
        session.platform = platform
        session.gameType = gameType
        session.blinds = blinds
        session.tableSize = Int16(tableSize)
        session.tables = Int16(tables)
        session.startTime = startTime
        session.endTime = endTime
        session.duration = sessionDurationHours
        session.balanceBefore = Double(balanceBefore) ?? 0
        session.balanceAfter = Double(balanceAfter) ?? 0
        session.netProfitLoss = netResult
        session.exchangeRateToBase = Double(exchangeRate) ?? 1.0
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
        session.blinds = blinds
        session.tableSize = Int16(tableSize)
        session.tables = Int16(tables)
        session.balanceBefore = Double(balanceBefore) ?? 0
        session.balanceAfter = Double(balanceAfter) ?? 0
        session.exchangeRateToBase = Double(exchangeRate) ?? 1.0
        session.notes = notes.isEmpty ? nil : notes
        try? viewContext.save()
    }

    func syncExchangeRate() {
        guard let platform = selectedPlatform else { return }
        if platform.displayCurrency == baseCurrency { exchangeRate = "1.0000" }
    }

    func checkBalanceDiscrepancy() {
        guard let platform = selectedPlatform else { return }
        let entered = Double(balanceBefore) ?? 0
        let recorded = platform.currentBalance
        if abs(entered - recorded) > 0.01 {
            discrepancyEnteredBalance = entered
            discrepancyRecordedBalance = recorded
            showBalanceDiscrepancy = true
        }
    }

    func logDiscrepancyAsAdjustment() {
        guard let platform = selectedPlatform else { return }
        let diff = discrepancyEnteredBalance - discrepancyRecordedBalance
        let adjustment = Adjustment(context: viewContext)
        adjustment.id = UUID()
        adjustment.name = "Discrepancy Fix"
        adjustment.amount = diff
        adjustment.date = Date()
        adjustment.currency = platform.displayCurrency
        adjustment.exchangeRateToBase = Double(exchangeRate) ?? 1.0
        adjustment.amountBase = diff * (Double(exchangeRate) ?? 1.0)
        adjustment.isOnline = true
        adjustment.platform = platform
        platform.currentBalance = discrepancyEnteredBalance
        try? viewContext.save()
    }

    func loadFromExisting(_ session: OnlineCash) {
        coreDataSession = session
        selectedPlatform = session.platform
        gameType = session.gameType ?? "No Limit Hold'em"
        blinds = session.blinds ?? ""
        tableSize = Int(session.tableSize)
        tables = Int(session.tables)
        balanceBefore = session.balanceBefore > 0 ? String(session.balanceBefore) : ""
        balanceAfter = session.balanceAfter > 0 ? String(session.balanceAfter) : ""
        exchangeRate = AppFormatter.exchangeRate(session.exchangeRateToBase)
        handsOverride = session.handsCount > 0 ? String(session.handsCount) : ""
        notes = session.notes ?? ""
        startTime = session.startTime ?? Date()
        entryState = .active
    }
}
