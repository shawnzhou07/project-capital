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

    // Timing
    @State private var sessionStartTime: Date? = nil
    @State private var sessionEndTime: Date? = nil

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
    @State private var showPlatformPicker = false
    @State private var tick = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // MARK: - Computed

    var platformCurrency: String {
        selectedPlatform?.displayCurrency ?? "USD"
    }

    var isSameCurrency: Bool {
        platformCurrency == baseCurrency
    }

    var netPL: Double {
        (Double(balanceAfter) ?? 0) - (Double(balanceBefore) ?? 0)
    }

    var netPLBase: Double {
        netPL * (Double(exchangeRate) ?? 1.0)
    }

    var sessionDurationHours: Double {
        guard let start = sessionStartTime else { return 0 }
        let end = sessionEndTime ?? tick
        return max(0, end.timeIntervalSince(start) / 3600.0)
    }

    var estimatedHands: Int {
        let settings = UserSettings.shared
        return Int(sessionDurationHours * Double(settings.handsPerHourOnline) * Double(tables))
    }

    var elapsedText: String {
        let totalMinutes = Int(sessionDurationHours * 60)
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        return "\(h)h \(m)m"
    }

    var isValid: Bool {
        selectedPlatform != nil && !blinds.isEmpty
    }

    var hasData: Bool {
        selectedPlatform != nil || !blinds.isEmpty || !balanceBefore.isEmpty || !balanceAfter.isEmpty || !notes.isEmpty
    }

    // MARK: - Body

    var body: some View {
        Form {
            platformSection
            sessionDetailsSection
            timingStatusSection
            balanceSection
            handsSection
            notesSection
            if entryState == .stopped {
                saveSection
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle("Online Session")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if entryState == .active {
                    Button {
                        coordinator.dismissForm()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.appGold)
                    }
                } else {
                    Button {
                        if entryState == .preStart && hasData {
                            showDiscardAlert = true
                        } else if entryState == .stopped {
                            showDiscardAlert = true
                        } else {
                            coordinator.dismissForm()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.appSecondary)
                    }
                }
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
            Button("Discard", role: .destructive) {
                discardSession()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All entered data will be lost.")
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
            if entryState == .active {
                tick = t
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
                    Text("Platform")
                        .foregroundColor(.appPrimary)
                    Spacer()
                    Text(selectedPlatform?.displayName ?? "Select...")
                        .foregroundColor(selectedPlatform == nil ? .appSecondary : .appGold)
                    if selectedPlatform != nil {
                        Text("·")
                            .foregroundColor(.appSecondary)
                        Text(platformCurrency)
                            .foregroundColor(.appSecondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                }
            }
            .listRowBackground(Color.appSurface)

            if !isSameCurrency {
                HStack {
                    Text("Exchange Rate")
                        .foregroundColor(.appPrimary)
                    Spacer()
                    TextField("1.0000", text: $exchangeRate)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.appGold)
                        .frame(width: 100)
                        .onChange(of: exchangeRate) { _, _ in autoSaveIfActive() }
                    Text("\(platformCurrency)/\(baseCurrency)")
                        .font(.caption)
                        .foregroundColor(.appSecondary)
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
                Text("Blinds")
                    .foregroundColor(.appPrimary)
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

    @ViewBuilder
    var timingStatusSection: some View {
        switch entryState {
        case .preStart:
            EmptyView()
        case .active:
            Section {
                HStack {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.appGold)
                            .frame(width: 8, height: 8)
                        Text("Session Active")
                            .foregroundColor(.appPrimary)
                    }
                    Spacer()
                    Text(elapsedText)
                        .foregroundColor(.appGold)
                        .fontWeight(.medium)
                        .monospacedDigit()
                }
                .listRowBackground(Color.appSurface)
            } header: {
                Text("Timing").foregroundColor(.appGold).textCase(nil)
            }
        case .stopped:
            Section {
                HStack {
                    Text("Duration")
                        .foregroundColor(.appPrimary)
                    Spacer()
                    Text(AppFormatter.duration(sessionDurationHours))
                        .foregroundColor(.appSecondary)
                }
                .listRowBackground(Color.appSurface)
            } header: {
                Text("Timing").foregroundColor(.appGold).textCase(nil)
            }
        }
    }

    var balanceSection: some View {
        Section {
            HStack {
                Text("Balance Before")
                    .foregroundColor(.appPrimary)
                Spacer()
                Text(platformCurrency)
                    .font(.caption)
                    .foregroundColor(.appSecondary)
                TextField("0.00", text: $balanceBefore)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.appPrimary)
                    .frame(width: 100)
                    .onChange(of: balanceBefore) { _, _ in autoSaveIfActive() }
            }
            .listRowBackground(Color.appSurface)

            HStack {
                Text("Balance After")
                    .foregroundColor(.appPrimary)
                Spacer()
                Text(platformCurrency)
                    .font(.caption)
                    .foregroundColor(.appSecondary)
                TextField("0.00", text: $balanceAfter)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.appPrimary)
                    .frame(width: 100)
                    .onChange(of: balanceAfter) { _, _ in autoSaveIfActive() }
            }
            .listRowBackground(Color.appSurface)

            HStack {
                Text("Net P&L")
                    .foregroundColor(.appPrimary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(AppFormatter.currencySigned(netPL, code: platformCurrency))
                        .fontWeight(.semibold)
                        .foregroundColor(netPL.profitColor)
                    if !isSameCurrency {
                        Text(AppFormatter.currencySigned(netPLBase, code: baseCurrency))
                            .font(.caption)
                            .foregroundColor(netPLBase.profitColor)
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
                Text("Hands Played")
                    .foregroundColor(.appPrimary)
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

    var saveSection: some View {
        Section {
            Button {
                saveFinal()
            } label: {
                Text("Save Session")
                    .font(.headline)
                    .foregroundColor(isValid ? .black : .appSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .disabled(!isValid)
            .listRowBackground(isValid ? Color.appGold : Color.appSurface2)
        }
    }

    // MARK: - Actions

    func handleStart() {
        guard let platform = selectedPlatform else { return }
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
        session.startTime = Date()

        do {
            try viewContext.save()
            coreDataSession = session
            sessionStartTime = session.startTime
            entryState = .active
        } catch {
            print("Start error: \(error)")
        }
    }

    func handleStop() {
        guard let session = coreDataSession else { return }
        let end = Date()
        session.endTime = end
        session.duration = max(0, end.timeIntervalSince(session.startTime ?? end) / 3600.0)
        do {
            try viewContext.save()
            sessionEndTime = end
            entryState = .stopped
        } catch {
            print("Stop error: \(error)")
        }
    }

    func saveFinal() {
        guard let session = coreDataSession, let platform = selectedPlatform else { return }
        session.platform = platform
        session.gameType = gameType
        session.blinds = blinds
        session.tableSize = Int16(tableSize)
        session.tables = Int16(tables)
        session.balanceBefore = Double(balanceBefore) ?? 0
        session.balanceAfter = Double(balanceAfter) ?? 0
        session.netProfitLoss = netPL
        session.exchangeRateToBase = Double(exchangeRate) ?? 1.0
        session.netProfitLossBase = netPLBase
        session.handsCount = Int32(handsOverride) ?? 0
        session.notes = notes.isEmpty ? nil : notes
        session.duration = sessionDurationHours

        // Update platform balance
        platform.currentBalance = Double(balanceAfter) ?? platform.currentBalance

        do {
            try viewContext.save()
            coordinator.dismissForm()
        } catch {
            print("Save error: \(error)")
        }
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
        if platform.displayCurrency == baseCurrency {
            exchangeRate = "1.0000"
        }
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
        sessionStartTime = session.startTime
        entryState = .active
    }
}
