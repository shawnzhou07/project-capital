import SwiftUI
import CoreData
import Combine

struct LiveSessionEntryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var coordinator: ActiveSessionCoordinator
    @AppStorage("baseCurrency") private var baseCurrency = "CAD"

    // Optional: passed when re-expanding from floating bar
    var existingSession: LiveCash? = nil

    enum EntryState { case preStart, active, stopped }

    @State private var entryState: EntryState = .preStart
    @State private var coreDataSession: LiveCash? = nil

    // Timing
    @State private var sessionStartTime: Date? = nil
    @State private var sessionEndTime: Date? = nil

    // Form fields
    @State private var location = ""
    @State private var currency = "CAD"
    @State private var exchangeRate = "1.0000"
    @State private var gameType = "No Limit Hold'em"
    @State private var blinds = ""
    @State private var tableSize = 9
    @State private var buyIn = ""
    @State private var cashOut = ""
    @State private var tips = "0"
    @State private var handsOverride = ""
    @State private var notes = ""

    @State private var showDiscardAlert = false
    @State private var tick = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // MARK: - Computed

    var isSameCurrency: Bool { currency == baseCurrency }

    var netPL: Double {
        (Double(cashOut) ?? 0) - (Double(buyIn) ?? 0) - (Double(tips) ?? 0)
    }

    var netPLBase: Double {
        netPL * (Double(exchangeRate) ?? 1.0)
    }

    var estimatedHands: Int {
        let hours = sessionDurationHours
        return Int(max(0, hours) * Double(UserSettings.shared.handsPerHourLive))
    }

    var sessionDurationHours: Double {
        guard let start = sessionStartTime else { return 0 }
        let end = sessionEndTime ?? tick
        return max(0, end.timeIntervalSince(start) / 3600.0)
    }

    var elapsedText: String {
        let totalMinutes = Int(sessionDurationHours * 60)
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        return "\(h)h \(m)m"
    }

    var isValid: Bool {
        !location.isEmpty && !blinds.isEmpty
    }

    var hasData: Bool {
        !location.isEmpty || !blinds.isEmpty || !buyIn.isEmpty || !cashOut.isEmpty || !notes.isEmpty
    }

    // MARK: - Body

    var body: some View {
        Form {
            locationSection
            sessionDetailsSection
            timingStatusSection
            financialsSection
            handsSection
            notesSection
            if entryState == .stopped {
                saveSection
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle("Live Session")
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
            currency = baseCurrency
            if let session = existingSession {
                loadFromExisting(session)
            }
        }
        .onReceive(timer) { t in
            if entryState == .active {
                tick = t
            }
        }
    }

    // MARK: - Form Sections

    var locationSection: some View {
        Section {
            HStack {
                TextField("Casino name or location", text: $location)
                    .foregroundColor(.appPrimary)
                    .onChange(of: location) { _, _ in autoSaveIfActive() }
            }
            .listRowBackground(Color.appSurface)

            Picker("Currency", selection: $currency) {
                ForEach(supportedCurrencies, id: \.self) { c in
                    Text(c).tag(c)
                }
            }
            .foregroundColor(.appPrimary)
            .tint(.appGold)
            .listRowBackground(Color.appSurface)
            .onChange(of: currency) { _, _ in autoSaveIfActive() }

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
                    Text("\(currency)/\(baseCurrency)")
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                }
                .listRowBackground(Color.appSurface)
            }
        } header: {
            Text("Location").foregroundColor(.appGold).textCase(nil)
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

    var financialsSection: some View {
        Section {
            HStack {
                Text("Buy In")
                    .foregroundColor(.appPrimary)
                Spacer()
                Text(currency)
                    .font(.caption)
                    .foregroundColor(.appSecondary)
                TextField("0.00", text: $buyIn)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.appPrimary)
                    .frame(width: 100)
                    .onChange(of: buyIn) { _, _ in autoSaveIfActive() }
            }
            .listRowBackground(Color.appSurface)

            HStack {
                Text("Cash Out")
                    .foregroundColor(.appPrimary)
                Spacer()
                Text(currency)
                    .font(.caption)
                    .foregroundColor(.appSecondary)
                TextField("0.00", text: $cashOut)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.appPrimary)
                    .frame(width: 100)
                    .onChange(of: cashOut) { _, _ in autoSaveIfActive() }
            }
            .listRowBackground(Color.appSurface)

            HStack {
                Text("Tips")
                    .foregroundColor(.appPrimary)
                Spacer()
                Text(currency)
                    .font(.caption)
                    .foregroundColor(.appSecondary)
                TextField("0.00", text: $tips)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.appPrimary)
                    .frame(width: 100)
                    .onChange(of: tips) { _, _ in autoSaveIfActive() }
            }
            .listRowBackground(Color.appSurface)

            HStack {
                Text("Net P&L")
                    .foregroundColor(.appPrimary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(AppFormatter.currencySigned(netPL, code: currency))
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
            Text("Financials").foregroundColor(.appGold).textCase(nil)
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
        let session = LiveCash(context: viewContext)
        session.id = UUID()
        session.location = location
        session.currency = currency
        session.exchangeRateToBase = Double(exchangeRate) ?? 1.0
        session.gameType = gameType
        session.blinds = blinds
        session.tableSize = Int16(tableSize)
        session.buyIn = Double(buyIn) ?? 0
        session.cashOut = Double(cashOut) ?? 0
        session.tips = Double(tips) ?? 0
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
        guard let session = coreDataSession else { return }
        session.location = location
        session.currency = currency
        session.exchangeRateToBase = Double(exchangeRate) ?? 1.0
        session.gameType = gameType
        session.blinds = blinds
        session.tableSize = Int16(tableSize)
        session.buyIn = Double(buyIn) ?? 0
        session.cashOut = Double(cashOut) ?? 0
        session.tips = Double(tips) ?? 0
        session.netProfitLoss = netPL
        session.netProfitLossBase = netPLBase
        session.handsCount = Int32(handsOverride) ?? 0
        session.notes = notes.isEmpty ? nil : notes
        session.duration = sessionDurationHours

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
        guard entryState == .active, let session = coreDataSession else { return }
        session.location = location
        session.currency = currency
        session.exchangeRateToBase = Double(exchangeRate) ?? 1.0
        session.gameType = gameType
        session.blinds = blinds
        session.tableSize = Int16(tableSize)
        session.buyIn = Double(buyIn) ?? 0
        session.cashOut = Double(cashOut) ?? 0
        session.tips = Double(tips) ?? 0
        session.notes = notes.isEmpty ? nil : notes
        try? viewContext.save()
    }

    func loadFromExisting(_ session: LiveCash) {
        coreDataSession = session
        location = session.location ?? ""
        currency = session.currency ?? baseCurrency
        exchangeRate = AppFormatter.exchangeRate(session.exchangeRateToBase)
        gameType = session.gameType ?? "No Limit Hold'em"
        blinds = session.blinds ?? ""
        tableSize = Int(session.tableSize)
        buyIn = session.buyIn > 0 ? String(session.buyIn) : ""
        cashOut = session.cashOut > 0 ? String(session.cashOut) : ""
        tips = session.tips > 0 ? String(session.tips) : "0"
        handsOverride = session.handsCount > 0 ? String(session.handsCount) : ""
        notes = session.notes ?? ""
        sessionStartTime = session.startTime
        entryState = .active
    }
}
