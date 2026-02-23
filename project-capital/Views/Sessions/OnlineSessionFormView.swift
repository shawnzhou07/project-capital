import SwiftUI
import CoreData

struct OnlineSessionFormView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("baseCurrency") private var baseCurrency = "CAD"

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Platform.name, ascending: true)],
        animation: .default
    ) private var platforms: FetchedResults<Platform>

    let onSave: () -> Void

    @State private var selectedPlatform: Platform? = nil
    @State private var gameType = "No Limit Hold'em"
    @State private var blinds = ""
    @State private var tableSize = 6
    @State private var tables = 1
    @State private var startTime = Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date()
    @State private var endTime = Date()
    @State private var balanceBefore = ""
    @State private var balanceAfter = ""
    @State private var exchangeRate = "1.0000"
    @State private var handsOverride = ""
    @State private var notes = ""
    @State private var showPlatformPicker = false

    var duration: Double {
        endTime.timeIntervalSince(startTime) / 3600.0
    }

    var netPL: Double {
        let before = Double(balanceBefore) ?? 0
        let after = Double(balanceAfter) ?? 0
        return after - before
    }

    var netPLBase: Double {
        netPL * (Double(exchangeRate) ?? 1.0)
    }

    var platformCurrency: String {
        selectedPlatform?.displayCurrency ?? "USD"
    }

    var isSameCurrency: Bool {
        platformCurrency == baseCurrency
    }

    var estimatedHands: Int {
        let settings = UserSettings.shared
        return Int(duration * Double(settings.handsPerHourOnline) * Double(tables))
    }

    var isValid: Bool {
        selectedPlatform != nil && !blinds.isEmpty && endTime > startTime
    }

    var body: some View {
        Form {
            platformSection
            sessionDetailsSection
            timingSection
            balanceSection
            handsSection
            notesSection
            saveSection
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .onAppear {
            if selectedPlatform == nil, let first = platforms.first {
                selectedPlatform = first
                syncExchangeRate()
            }
        }
    }

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

            HStack {
                Text("Blinds")
                    .foregroundColor(.appPrimary)
                Spacer()
                TextField("$1/$2", text: $blinds)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.appGold)
            }
            .listRowBackground(Color.appSurface)

            Stepper("Table Size: \(tableSize)", value: $tableSize, in: 2...10)
                .foregroundColor(.appPrimary)
                .listRowBackground(Color.appSurface)

            Stepper("Tables: \(tables)", value: $tables, in: 1...10)
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

    func syncExchangeRate() {
        guard let platform = selectedPlatform else { return }
        if platform.displayCurrency == baseCurrency {
            exchangeRate = "1.0000"
        }
    }

    func saveSession() {
        guard let platform = selectedPlatform else { return }
        let session = OnlineCash(context: viewContext)
        session.id = UUID()
        session.platform = platform
        session.gameType = gameType
        session.blinds = blinds
        session.tableSize = Int16(tableSize)
        session.tables = Int16(tables)
        session.startTime = startTime
        session.endTime = endTime
        session.duration = max(0, duration)
        session.balanceBefore = Double(balanceBefore) ?? 0
        session.balanceAfter = Double(balanceAfter) ?? 0
        session.netProfitLoss = netPL
        session.exchangeRateToBase = Double(exchangeRate) ?? 1.0
        session.netProfitLossBase = netPLBase
        session.handsCount = Int32(handsOverride) ?? 0
        session.notes = notes.isEmpty ? nil : notes

        // Update platform balance
        platform.currentBalance = session.balanceAfter

        do {
            try viewContext.save()
            onSave()
        } catch {
            print("Save error: \(error)")
        }
    }
}

struct PlatformPickerSheet: View {
    let platforms: [Platform]
    @Binding var selected: Platform?
    let onSelect: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                List {
                    ForEach(platforms) { platform in
                        Button {
                            selected = platform
                            onSelect()
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(platform.displayName)
                                        .foregroundColor(.appPrimary)
                                    Text(platform.displayCurrency)
                                        .font(.caption)
                                        .foregroundColor(.appSecondary)
                                }
                                Spacer()
                                if selected == platform {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.appGold)
                                }
                            }
                        }
                        .listRowBackground(Color.appSurface)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Select Platform")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.appSecondary)
                }
            }
        }
    }
}
