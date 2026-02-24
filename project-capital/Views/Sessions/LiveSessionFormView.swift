import SwiftUI
import CoreData
import CoreLocation

struct LiveSessionFormView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("baseCurrency") private var baseCurrency = "CAD"

    let onSave: () -> Void

    @State private var location = ""
    @State private var currency = "CAD"
    @State private var exchangeRate = "1.0000"
    @State private var gameType = "No Limit Hold'em"
    @State private var smallBlind = ""
    @State private var bigBlind = ""
    @State private var straddle = ""
    @State private var ante = ""
    @State private var tableSize = 9
    @State private var startTime = Calendar.current.date(byAdding: .hour, value: -4, to: Date()) ?? Date()
    @State private var endTime = Date()
    @State private var prevStartTime = Calendar.current.date(byAdding: .hour, value: -4, to: Date()) ?? Date()
    @State private var prevEndTime = Date()
    @State private var buyIn = ""
    @State private var cashOut = ""
    @State private var tips = ""
    @State private var breakTimeStr = ""
    @State private var handsOverride = ""
    @State private var notes = ""
    @State private var showTimeAlert = false

    var breakTimeMinutes: Double { Double(breakTimeStr) ?? 0 }

    var duration: Double {
        let raw = endTime.timeIntervalSince(startTime) / 3600.0
        return max(0, raw - breakTimeMinutes / 60.0)
    }

    // Net P&L excludes tips (tips are record-keeping only)
    var netPL: Double {
        (Double(cashOut) ?? 0) - (Double(buyIn) ?? 0)
    }

    var netPLBase: Double {
        netPL * (Double(exchangeRate) ?? 1.0)
    }

    var isSameCurrency: Bool { currency == baseCurrency }

    var estimatedHands: Int {
        Int(max(0, duration) * Double(UserSettings.shared.handsPerHourLive))
    }

    var sbDouble: Double { Double(smallBlind) ?? 0 }
    var bbDouble: Double { Double(bigBlind) ?? 0 }

    var isValid: Bool {
        !location.isEmpty && sbDouble > 0 && bbDouble > 0 && endTime > startTime
    }

    var body: some View {
        Form {
            locationSection
            sessionDetailsSection
            timingSection
            financialsSection
            handsSection
            notesSection
            saveSection
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .selectAllOnFocus()
        .onAppear {
            currency = baseCurrency
            prevStartTime = startTime
            prevEndTime = endTime
        }
        .alert("Invalid Time Range", isPresented: $showTimeAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("End time must be after start time.")
        }
    }

    var locationSection: some View {
        Section {
            HStack {
                TextField("Casino name or location", text: $location)
                    .foregroundColor(.appPrimary)
                Button {
                    requestLocation()
                } label: {
                    Image(systemName: "location.fill")
                        .foregroundColor(.appGold)
                }
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

            if !isSameCurrency {
                HStack {
                    Text("Exchange Rate")
                        .foregroundColor(.appPrimary)
                    Spacer()
                    TextField("1.0000", text: $exchangeRate)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.white)
                        .frame(width: 100)
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

            HStack(spacing: 12) {
                blindField(label: "SB", text: $smallBlind)
                blindField(label: "BB", text: $bigBlind)
                blindField(label: "3rd (Opt.)", text: $straddle)
                blindField(label: "Ante (Opt.)", text: $ante)
            }
            .listRowBackground(Color.appSurface)

            Stepper("Table Size: \(tableSize)", value: $tableSize, in: 2...10)
                .foregroundColor(.appPrimary)
                .listRowBackground(Color.appSurface)
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
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.appSurface2)
                .cornerRadius(6)
        }
    }

    var timingSection: some View {
        Section {
            DatePicker("Start", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                .foregroundColor(.appPrimary)
                .tint(.appGold)
                .listRowBackground(Color.appSurface)
                .onChange(of: startTime) { oldVal, newVal in
                    // Midnight rollover detection: time wrapped from ~23:59 to ~00:00
                    if oldVal.timeIntervalSince(newVal) > 20 * 3600 {
                        startTime = Calendar.current.date(byAdding: .day, value: 1, to: newVal) ?? newVal
                        return
                    }
                    if endTime <= startTime {
                        showTimeAlert = true
                        startTime = prevStartTime
                    } else {
                        prevStartTime = startTime
                    }
                }

            DatePicker("End", selection: $endTime, displayedComponents: [.date, .hourAndMinute])
                .foregroundColor(.appPrimary)
                .tint(.appGold)
                .listRowBackground(Color.appSurface)
                .onChange(of: endTime) { oldVal, newVal in
                    if oldVal.timeIntervalSince(newVal) > 20 * 3600 {
                        endTime = Calendar.current.date(byAdding: .day, value: 1, to: newVal) ?? newVal
                        return
                    }
                    if endTime <= startTime {
                        showTimeAlert = true
                        endTime = prevEndTime
                    } else {
                        prevEndTime = endTime
                    }
                }

            HStack {
                Text("Break (min)")
                    .foregroundColor(.appPrimary)
                Spacer()
                TextField("0", text: $breakTimeStr)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.white)
                    .frame(width: 80)
            }
            .listRowBackground(Color.appSurface)

            HStack {
                Text("Duration")
                    .foregroundColor(.appPrimary)
                Spacer()
                Text(AppFormatter.duration(duration))
                    .foregroundColor(.appSecondary)
            }
            .listRowBackground(Color.appSurface)
        } header: {
            Text("Timing").foregroundColor(.appGold).textCase(nil)
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
                TextField("0", text: $buyIn)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.appPrimary)
                    .frame(width: 100)
            }
            .listRowBackground(Color.appSurface)

            HStack {
                Text("Cash Out")
                    .foregroundColor(.appPrimary)
                Spacer()
                Text(currency)
                    .font(.caption)
                    .foregroundColor(.appSecondary)
                TextField("0", text: $cashOut)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.appPrimary)
                    .frame(width: 100)
            }
            .listRowBackground(Color.appSurface)

            HStack {
                Text("Tips")
                    .foregroundColor(.appPrimary)
                Spacer()
                Text(currency)
                    .font(.caption)
                    .foregroundColor(.appSecondary)
                TextField("0", text: $tips)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.appPrimary)
                    .frame(width: 100)
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
                    .foregroundColor(.white)
                    .frame(width: 140)
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
        } header: {
            Text("Notes").foregroundColor(.appGold).textCase(nil)
        }
    }

    var saveSection: some View {
        Section {
            Button {
                saveSession()
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

    func requestLocation() {
        let manager = CLLocationManager()
        manager.requestWhenInUseAuthorization()
    }

    func saveSession() {
        guard endTime > startTime else { showTimeAlert = true; return }
        let session = LiveCash(context: viewContext)
        session.id = UUID()
        session.location = location
        session.currency = currency
        let rate = Double(exchangeRate) ?? 1.0
        session.exchangeRateToBase = rate
        session.exchangeRateBuyIn = rate
        session.exchangeRateCashOut = rate
        session.gameType = gameType
        session.smallBlind = sbDouble
        session.bigBlind = bbDouble
        session.straddle = Double(straddle) ?? 0
        session.ante = Double(ante) ?? 0
        session.tableSize = Int16(tableSize)
        session.startTime = startTime
        session.endTime = endTime
        session.breakTime = breakTimeMinutes
        session.duration = duration
        session.buyIn = Double(buyIn) ?? 0
        session.cashOut = Double(cashOut) ?? 0
        session.tips = Double(tips) ?? 0
        session.netProfitLoss = netPL
        session.netProfitLossBase = netPLBase
        session.handsCount = Int32(handsOverride) ?? 0
        session.notes = notes.isEmpty ? nil : notes

        do {
            try viewContext.save()
            onSave()
        } catch {
            print("Save error: \(error)")
        }
    }
}
