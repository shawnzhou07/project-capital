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
    @State private var blinds = ""
    @State private var tableSize = 9
    @State private var startTime = Calendar.current.date(byAdding: .hour, value: -4, to: Date()) ?? Date()
    @State private var endTime = Date()
    @State private var buyIn = ""
    @State private var cashOut = ""
    @State private var tips = "0"
    @State private var handsOverride = ""
    @State private var notes = ""

    var duration: Double {
        endTime.timeIntervalSince(startTime) / 3600.0
    }

    var netPL: Double {
        (Double(cashOut) ?? 0) - (Double(buyIn) ?? 0) - (Double(tips) ?? 0)
    }

    var netPLBase: Double {
        netPL * (Double(exchangeRate) ?? 1.0)
    }

    var isSameCurrency: Bool { currency == baseCurrency }

    var estimatedHands: Int {
        Int(max(0, duration) * Double(UserSettings.shared.handsPerHourLive))
    }

    var isValid: Bool {
        !location.isEmpty && !blinds.isEmpty && endTime > startTime
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
        .onAppear {
            currency = baseCurrency
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
                        .foregroundColor(.appGold)
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

            HStack {
                Text("Blinds")
                    .foregroundColor(.appPrimary)
                Spacer()
                TextField("1/2", text: $blinds)
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

    var timingSection: some View {
        Section {
            DatePicker("Start Time", selection: $startTime)
                .foregroundColor(.appPrimary)
                .tint(.appGold)
                .listRowBackground(Color.appSurface)

            DatePicker("End Time", selection: $endTime)
                .foregroundColor(.appPrimary)
                .tint(.appGold)
                .listRowBackground(Color.appSurface)

            HStack {
                Text("Duration")
                    .foregroundColor(.appPrimary)
                Spacer()
                Text(AppFormatter.duration(max(0, duration)))
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
                TextField("0.00", text: $buyIn)
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
                TextField("0.00", text: $cashOut)
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
                TextField("0.00", text: $tips)
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
                    .foregroundColor(.appGold)
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
        // Basic GPS suggestion — in production, use CLGeocoder with nearby POI search
        let manager = CLLocationManager()
        manager.requestWhenInUseAuthorization()
        // Placeholder — would normally do a reverse geocode here
        // For now just focus the location field for user input
    }

    func saveSession() {
        let session = LiveCash(context: viewContext)
        session.id = UUID()
        session.location = location
        session.currency = currency
        session.exchangeRateToBase = Double(exchangeRate) ?? 1.0
        session.gameType = gameType
        session.blinds = blinds
        session.tableSize = Int16(tableSize)
        session.startTime = startTime
        session.endTime = endTime
        session.duration = max(0, duration)
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
