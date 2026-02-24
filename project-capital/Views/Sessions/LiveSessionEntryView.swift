import SwiftUI
import CoreData
import Combine

struct LiveSessionEntryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var coordinator: ActiveSessionCoordinator
    @AppStorage("baseCurrency") private var baseCurrency = "CAD"
    @AppStorage("exchangeRateInputMode") private var exchangeRateInputMode = "direct"

    // Optional: passed when re-expanding from floating bar
    var existingSession: LiveCash? = nil

    enum EntryState { case preStart, active, stopped }

    @State private var entryState: EntryState = .preStart
    @State private var coreDataSession: LiveCash? = nil

    // Timing state vars (always editable)
    @State private var startTime = Date()
    @State private var endTime = Date()

    // Form fields
    @State private var location = ""
    @State private var currency = "CAD"
    // Dual exchange rates
    @State private var exchangeRateBuyInStr = "1.0000"
    @State private var exchangeRateCashOutStr = "1.0000"
    // Mode B: base currency amounts
    @State private var buyInBaseStr = ""
    @State private var cashOutBaseStr = ""
    @State private var cashOutRateManuallySet = false

    @State private var gameType = "No Limit Hold'em"
    @State private var smallBlind = ""
    @State private var bigBlind = ""
    @State private var straddle = ""
    @State private var ante = ""
    @State private var breakTimeStr = ""
    @State private var tableSize = 9
    @State private var buyIn = ""
    @State private var cashOut = ""
    @State private var tips = "0"
    @State private var handsOverride = ""
    @State private var notes = ""

    @State private var showDiscardAlert = false
    @State private var showRequiredFieldsAlert = false
    @State private var tick = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // MARK: - Computed

    var isSameCurrency: Bool { currency == baseCurrency }
    var exchangeRateBuyIn: Double { Double(exchangeRateBuyInStr) ?? 1.0 }
    var exchangeRateCashOut: Double { Double(exchangeRateCashOutStr) ?? 1.0 }
    var buyInDouble: Double { Double(buyIn) ?? 0 }
    var cashOutDouble: Double { Double(cashOut) ?? 0 }
    var buyInBase: Double { buyInDouble * exchangeRateBuyIn }
    var cashOutBase: Double { cashOutDouble * exchangeRateCashOut }
    var sbDouble: Double { Double(smallBlind) ?? 0 }
    var bbDouble: Double { Double(bigBlind) ?? 0 }
    var breakTimeMinutes: Double { Double(breakTimeStr) ?? 0 }

    var netResult: Double { cashOutDouble - buyInDouble }
    var netResultBase: Double { (cashOutDouble * exchangeRateCashOut) - (buyInDouble * exchangeRateBuyIn) }

    var estimatedHands: Int {
        Int(max(0, sessionDurationHours) * Double(UserSettings.shared.handsPerHourLive))
    }

    var sessionDurationHours: Double {
        switch entryState {
        case .preStart: return 0
        case .active: return max(0, tick.timeIntervalSince(startTime) / 3600.0)
        case .stopped: return max(0, endTime.timeIntervalSince(startTime) / 3600.0 - breakTimeMinutes / 60.0)
        }
    }

    var elapsedText: String {
        let totalMinutes = Int(sessionDurationHours * 60)
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        return "\(h)h \(m)m"
    }

    var isValidForSave: Bool {
        !location.isEmpty && sbDouble > 0 && bbDouble > 0
    }

    var hasData: Bool {
        !location.isEmpty || sbDouble > 0 || bbDouble > 0 || !buyIn.isEmpty || !cashOut.isEmpty || !notes.isEmpty
    }

    // MARK: - Body

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
                Text("Please fill in Location, SB, and BB before saving.")
            }
            .onAppear {
                currency = baseCurrency
                if let session = existingSession { loadFromExisting(session) }
            }
            .onChange(of: currency) { _, newCurrency in
                prefillExchangeRate(for: newCurrency)
                autoSaveIfActive()
            }
            .onChange(of: exchangeRateBuyInStr) { _, newVal in
                if !cashOutRateManuallySet { exchangeRateCashOutStr = newVal }
                autoSaveIfActive()
            }
            .onChange(of: exchangeRateCashOutStr) { old, new in
                if old != new && new != exchangeRateBuyInStr { cashOutRateManuallySet = true }
                autoSaveIfActive()
            }
            .onChange(of: buyInBaseStr) { _, _ in recalcRateFromAmounts(forBuyIn: true); autoSaveIfActive() }
            .onChange(of: cashOutBaseStr) { _, _ in recalcRateFromAmounts(forBuyIn: false); autoSaveIfActive() }
            .onReceive(timer) { t in if entryState == .active { tick = t } }
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
            locationSection
            sessionDetailsSection
            timingSection
            financialsSection
            if !isSameCurrency {
                exchangeRatesSection
            }
            handsSection
            notesSection
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .selectAllOnFocus()
        .navigationTitle("Live Session")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }

    @ViewBuilder
    private var trailingToolbarButton: some View {
        if entryState == .preStart {
            Button("Start") { handleStart() }
                .fontWeight(.semibold)
                .foregroundColor(.appGold)
        } else if entryState == .active {
            Button("Stop") { handleStop() }
                .fontWeight(.semibold)
                .foregroundColor(.appLoss)
        } else if entryState == .stopped {
            Button("Save") {
                if isValidForSave { saveFinal() } else { showRequiredFieldsAlert = true }
            }
            .fontWeight(.semibold)
            .foregroundColor(.appGold)
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

    var locationSection: some View {
        Section {
            HStack {
                TextField("Casino name or location", text: $location)
                    .foregroundColor(.appPrimary)
                    .onChange(of: location) { _, _ in autoSaveIfActive() }
            }
            .listRowBackground(Color.appSurface)

            Picker("Currency", selection: $currency) {
                ForEach(supportedCurrencies, id: \.self) { Text($0).tag($0) }
            }
            .foregroundColor(.appPrimary)
            .tint(.appGold)
            .listRowBackground(Color.appSurface)
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

            HStack(spacing: 12) {
                blindField(label: "SB", text: $smallBlind)
                blindField(label: "BB", text: $bigBlind)
                blindField(label: "Straddle", text: $straddle)
                blindField(label: "Ante", text: $ante)
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
    func blindField(label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.appSecondary)
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .foregroundColor(.appGold)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.appSurface2)
                .cornerRadius(6)
                .onChange(of: text.wrappedValue) { _, _ in autoSaveIfActive() }
        }
    }

    var timingSection: some View {
        Section {
            DatePicker("Start Time", selection: $startTime)
                .foregroundColor(.appPrimary)
                .tint(.appGold)
                .listRowBackground(Color.appSurface)
                .onChange(of: startTime) { _, _ in autoSaveIfActive() }

            DatePicker("End Time", selection: $endTime)
                .foregroundColor(.appPrimary)
                .tint(.appGold)
                .listRowBackground(Color.appSurface)
                .disabled(entryState != .stopped)
                .opacity(entryState == .stopped ? 1.0 : 0.4)

            HStack {
                Text("Break (min)").foregroundColor(.appPrimary)
                Spacer()
                TextField("0", text: $breakTimeStr)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.appGold)
                    .frame(width: 80)
                    .onChange(of: breakTimeStr) { _, _ in autoSaveIfActive() }
            }
            .listRowBackground(Color.appSurface)

            HStack {
                Text("Duration").foregroundColor(.appPrimary)
                Spacer()
                if entryState == .active {
                    HStack(spacing: 6) {
                        Circle().fill(Color.appGold).frame(width: 6, height: 6)
                        Text(elapsedText)
                            .foregroundColor(.appGold)
                            .fontWeight(.medium)
                            .monospacedDigit()
                    }
                } else if entryState == .stopped {
                    Text(AppFormatter.duration(sessionDurationHours))
                        .foregroundColor(.appSecondary)
                } else {
                    Text("—").foregroundColor(.appSecondary)
                }
            }
            .listRowBackground(Color.appSurface)
        } header: {
            Text("Timing").foregroundColor(.appGold).textCase(nil)
        }
    }

    var financialsSection: some View {
        Section {
            HStack {
                Text("Buy In").foregroundColor(.appPrimary)
                Spacer()
                Text(currency).font(.caption).foregroundColor(.appSecondary)
                TextField("0", text: $buyIn)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.appPrimary)
                    .frame(width: 100)
                    .onChange(of: buyIn) { _, _ in
                        if exchangeRateInputMode == "amounts" && exchangeRateBuyIn > 0 {
                            buyInBaseStr = String(format: "%.2f", buyInDouble * exchangeRateBuyIn)
                        }
                        autoSaveIfActive()
                    }
            }
            .listRowBackground(Color.appSurface)

            HStack {
                Text("Cash Out").foregroundColor(.appPrimary)
                Spacer()
                Text(currency).font(.caption).foregroundColor(.appSecondary)
                TextField("0", text: $cashOut)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.appPrimary)
                    .frame(width: 100)
                    .onChange(of: cashOut) { _, _ in
                        if exchangeRateInputMode == "amounts" && exchangeRateCashOut > 0 {
                            cashOutBaseStr = String(format: "%.2f", cashOutDouble * exchangeRateCashOut)
                        }
                        autoSaveIfActive()
                    }
            }
            .listRowBackground(Color.appSurface)

            HStack {
                Text("Tips").foregroundColor(.appPrimary)
                Spacer()
                Text(currency).font(.caption).foregroundColor(.appSecondary)
                TextField("0", text: $tips)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.appPrimary)
                    .frame(width: 100)
                    .onChange(of: tips) { _, _ in autoSaveIfActive() }
            }
            .listRowBackground(Color.appSurface)

            HStack {
                Text("Net Result").foregroundColor(.appPrimary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(AppFormatter.currencySigned(netResult, code: currency))
                        .fontWeight(.semibold)
                        .foregroundColor(netResult.profitColor)
                    if !isSameCurrency {
                        Text(AppFormatter.currencySigned(netResultBase, code: baseCurrency))
                            .font(.caption)
                            .foregroundColor(netResultBase.profitColor)
                    }
                }
            }
            .listRowBackground(Color.appSurface)
        } header: {
            Text("Financials").foregroundColor(.appGold).textCase(nil)
        }
    }

    var exchangeRatesSection: some View {
        Section {
            if exchangeRateInputMode == "direct" {
                HStack {
                    Text("Buy-In Rate").foregroundColor(.appPrimary)
                    Spacer()
                    TextField("1.0000", text: $exchangeRateBuyInStr)
                        .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        .foregroundColor(.appGold).frame(width: 90)
                    Text("\(currency)/\(baseCurrency)").font(.caption).foregroundColor(.appSecondary)
                }
                .listRowBackground(Color.appSurface)
                HStack {
                    Text("Buy-In Cost").font(.caption).foregroundColor(.appSecondary)
                    Spacer()
                    Text(AppFormatter.currency(buyInBase, code: baseCurrency)).font(.caption).foregroundColor(.appSecondary)
                }
                .listRowBackground(Color.appSurface).allowsHitTesting(false)
                HStack {
                    Text("Cash-Out Rate").foregroundColor(.appPrimary)
                    Spacer()
                    TextField("1.0000", text: $exchangeRateCashOutStr)
                        .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        .foregroundColor(.appGold).frame(width: 90)
                    Text("\(currency)/\(baseCurrency)").font(.caption).foregroundColor(.appSecondary)
                }
                .listRowBackground(Color.appSurface)
                HStack {
                    Text("Cash-Out Proceeds").font(.caption).foregroundColor(.appSecondary)
                    Spacer()
                    Text(AppFormatter.currency(cashOutBase, code: baseCurrency)).font(.caption).foregroundColor(.appSecondary)
                }
                .listRowBackground(Color.appSurface).allowsHitTesting(false)
            } else {
                Text("Buy-In Exchange").font(.caption).foregroundColor(.appGold).listRowBackground(Color.appSurface)
                HStack {
                    Text("Amount (\(currency))").foregroundColor(.appPrimary)
                    Spacer()
                    TextField("0", text: $buyIn).keyboardType(.decimalPad).multilineTextAlignment(.trailing).foregroundColor(.appGold).frame(width: 100)
                }
                .listRowBackground(Color.appSurface)
                HStack {
                    Text("Equivalent (\(baseCurrency))").foregroundColor(.appPrimary)
                    Spacer()
                    TextField("0", text: $buyInBaseStr).keyboardType(.decimalPad).multilineTextAlignment(.trailing).foregroundColor(.appGold).frame(width: 100)
                }
                .listRowBackground(Color.appSurface)
                HStack {
                    Text("Rate (calculated)").font(.caption).foregroundColor(.appSecondary)
                    Spacer()
                    Text(String(format: "%.4f", exchangeRateBuyIn)).font(.caption).foregroundColor(.appSecondary)
                    Text("\(currency)/\(baseCurrency)").font(.caption2).foregroundColor(.appSecondary)
                }
                .listRowBackground(Color.appSurface).allowsHitTesting(false)
                Text("Cash-Out Exchange").font(.caption).foregroundColor(.appGold).listRowBackground(Color.appSurface)
                HStack {
                    Text("Amount (\(currency))").foregroundColor(.appPrimary)
                    Spacer()
                    TextField("0", text: $cashOut).keyboardType(.decimalPad).multilineTextAlignment(.trailing).foregroundColor(.appGold).frame(width: 100)
                }
                .listRowBackground(Color.appSurface)
                HStack {
                    Text("Equivalent (\(baseCurrency))").foregroundColor(.appPrimary)
                    Spacer()
                    TextField("0", text: $cashOutBaseStr).keyboardType(.decimalPad).multilineTextAlignment(.trailing).foregroundColor(.appGold).frame(width: 100)
                }
                .listRowBackground(Color.appSurface)
                HStack {
                    Text("Rate (calculated)").font(.caption).foregroundColor(.appSecondary)
                    Spacer()
                    Text(String(format: "%.4f", exchangeRateCashOut)).font(.caption).foregroundColor(.appSecondary)
                    Text("\(currency)/\(baseCurrency)").font(.caption2).foregroundColor(.appSecondary)
                }
                .listRowBackground(Color.appSurface).allowsHitTesting(false)
            }
        } header: {
            Text("Exchange Rates").foregroundColor(.appGold).textCase(nil)
        } footer: {
            Text("Exchange rates are always editable.").foregroundColor(.appSecondary)
        }
    }

    var handsSection: some View {
        Section {
            HStack {
                Text("Hands Played").foregroundColor(.appPrimary)
                Spacer()
                TextField("Auto (\(estimatedHands) est.)", text: $handsOverride)
                    .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                    .foregroundColor(.appGold).frame(width: 140)
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

    func prefillExchangeRate(for newCurrency: String) {
        guard newCurrency != baseCurrency else { return }
        let defaultRate = UserSettings.shared.defaultExchangeRate(sessionCurrency: newCurrency, baseCurrency: baseCurrency)
        exchangeRateBuyInStr = String(format: "%.4f", defaultRate)
        exchangeRateCashOutStr = String(format: "%.4f", defaultRate)
        cashOutRateManuallySet = false
    }

    func recalcRateFromAmounts(forBuyIn: Bool) {
        if forBuyIn {
            let amt = Double(buyIn) ?? 0
            let base = Double(buyInBaseStr) ?? 0
            if amt > 0 && base > 0 {
                let rate = base / amt
                exchangeRateBuyInStr = String(format: "%.4f", rate)
                if !cashOutRateManuallySet { exchangeRateCashOutStr = String(format: "%.4f", rate) }
            }
        } else {
            let amt = Double(cashOut) ?? 0
            let base = Double(cashOutBaseStr) ?? 0
            if amt > 0 && base > 0 {
                exchangeRateCashOutStr = String(format: "%.4f", base / amt)
                cashOutRateManuallySet = true
            }
        }
    }

    func handleStart() {
        startTime = Date()
        let session = LiveCash(context: viewContext)
        session.id = UUID()
        session.location = location
        session.currency = currency
        session.exchangeRateBuyIn = exchangeRateBuyIn
        session.exchangeRateCashOut = exchangeRateCashOut
        session.exchangeRateToBase = exchangeRateCashOut
        session.gameType = gameType
        session.smallBlind = sbDouble
        session.bigBlind = bbDouble
        session.straddle = Double(straddle) ?? 0
        session.ante = Double(ante) ?? 0
        session.blinds = "\(AppFormatter.blindValue(sbDouble))/\(AppFormatter.blindValue(bbDouble))"
        session.tableSize = Int16(tableSize)
        session.buyIn = buyInDouble
        session.cashOut = cashOutDouble
        session.tips = Double(tips) ?? 0
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

    func saveFinal() {
        guard let session = coreDataSession else { return }
        session.location = location
        session.currency = currency
        session.exchangeRateBuyIn = exchangeRateBuyIn
        session.exchangeRateCashOut = exchangeRateCashOut
        session.exchangeRateToBase = exchangeRateCashOut
        session.gameType = gameType
        session.smallBlind = sbDouble
        session.bigBlind = bbDouble
        session.straddle = Double(straddle) ?? 0
        session.ante = Double(ante) ?? 0
        session.blinds = "\(AppFormatter.blindValue(sbDouble))/\(AppFormatter.blindValue(bbDouble))"
        session.tableSize = Int16(tableSize)
        session.startTime = startTime
        session.endTime = endTime
        session.breakTime = breakTimeMinutes
        session.duration = sessionDurationHours
        session.buyIn = buyInDouble
        session.cashOut = cashOutDouble
        session.tips = Double(tips) ?? 0
        session.netProfitLoss = netResult
        session.netProfitLossBase = netResultBase
        session.handsCount = Int32(handsOverride) ?? 0
        session.notes = notes.isEmpty ? nil : notes
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
        guard entryState == .active, let session = coreDataSession else { return }
        session.location = location
        session.currency = currency
        session.exchangeRateBuyIn = exchangeRateBuyIn
        session.exchangeRateCashOut = exchangeRateCashOut
        session.exchangeRateToBase = exchangeRateCashOut
        session.gameType = gameType
        session.smallBlind = sbDouble
        session.bigBlind = bbDouble
        session.straddle = Double(straddle) ?? 0
        session.ante = Double(ante) ?? 0
        session.blinds = "\(AppFormatter.blindValue(sbDouble))/\(AppFormatter.blindValue(bbDouble))"
        session.tableSize = Int16(tableSize)
        session.buyIn = buyInDouble
        session.cashOut = cashOutDouble
        session.tips = Double(tips) ?? 0
        session.notes = notes.isEmpty ? nil : notes
        try? viewContext.save()
    }

    func loadFromExisting(_ session: LiveCash) {
        coreDataSession = session
        location = session.location ?? ""
        currency = session.currency ?? baseCurrency
        gameType = session.gameType ?? "No Limit Hold'em"
        tableSize = Int(session.tableSize)
        buyIn = session.buyIn > 0 ? String(format: "%.2f", session.buyIn) : ""
        cashOut = session.cashOut > 0 ? String(format: "%.2f", session.cashOut) : ""
        tips = session.tips > 0 ? String(format: "%.2f", session.tips) : "0"
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

        if session.exchangeRateCashOut > 0 {
            exchangeRateBuyInStr = String(format: "%.4f", session.exchangeRateBuyIn > 0 ? session.exchangeRateBuyIn : session.exchangeRateCashOut)
            exchangeRateCashOutStr = String(format: "%.4f", session.exchangeRateCashOut)
            cashOutRateManuallySet = session.exchangeRateBuyIn != session.exchangeRateCashOut
        } else if session.exchangeRateToBase > 0 {
            exchangeRateBuyInStr = String(format: "%.4f", session.exchangeRateToBase)
            exchangeRateCashOutStr = String(format: "%.4f", session.exchangeRateToBase)
        }
        entryState = .active
    }
}
