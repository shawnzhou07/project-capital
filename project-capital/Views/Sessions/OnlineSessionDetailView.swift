import SwiftUI
import CoreData
import Combine

struct OnlineSessionDetailView: View {
    @ObservedObject var session: OnlineCash
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("baseCurrency") private var baseCurrency = "CAD"

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Platform.name, ascending: true)],
        animation: .default
    ) private var platforms: FetchedResults<Platform>

    @State private var showDeleteAlert = false
    @Environment(\.dismiss) private var dismiss

    // Editable state mirroring Core Data properties
    @State private var gameType = ""
    @State private var blinds = ""
    @State private var tableSize = 6
    @State private var tables = 1
    @State private var startTime = Date()
    @State private var endTime = Date()
    @State private var balanceBefore = ""
    @State private var balanceAfter = ""
    @State private var exchangeRate = ""
    @State private var handsOverride = ""
    @State private var notes = ""
    @State private var selectedPlatform: Platform? = nil
    @State private var showPlatformPicker = false
    @State private var loaded = false
    @State private var elapsed: TimeInterval = 0
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var duration: Double {
        endTime.timeIntervalSince(startTime) / 3600.0
    }
    var netPL: Double {
        (Double(balanceAfter) ?? 0) - (Double(balanceBefore) ?? 0)
    }
    var netPLBase: Double {
        netPL * (Double(exchangeRate) ?? 1.0)
    }
    var platformCurrency: String {
        selectedPlatform?.displayCurrency ?? session.platformCurrency
    }
    var isSameCurrency: Bool { platformCurrency == baseCurrency }
    var estimatedHands: Int {
        let s = UserSettings.shared
        return Int(duration * Double(s.handsPerHourOnline) * Double(tables))
    }
    var effectiveHands: Int {
        if let manual = Int(handsOverride), manual > 0 { return manual }
        return estimatedHands
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            Form {
                headerSection
                platformSection
                gameDetailsSection
                timingSection
                balanceSection
                handsSection
                notesSection
                deleteSection
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
        }
        .navigationTitle("Online Session")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadFromSession() }
        .onChange(of: gameType) { _, _ in autoSave() }
        .onChange(of: blinds) { _, _ in autoSave() }
        .onChange(of: tableSize) { _, _ in autoSave() }
        .onChange(of: tables) { _, _ in autoSave() }
        .onChange(of: startTime) { _, _ in autoSave() }
        .onChange(of: endTime) { _, _ in autoSave() }
        .onChange(of: balanceBefore) { _, _ in autoSave() }
        .onChange(of: balanceAfter) { _, _ in autoSave() }
        .onChange(of: exchangeRate) { _, _ in autoSave() }
        .onChange(of: handsOverride) { _, _ in autoSave() }
        .onChange(of: notes) { _, _ in autoSave() }
        .onChange(of: selectedPlatform) { _, _ in autoSave() }
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
        .sheet(isPresented: $showPlatformPicker) {
            PlatformPickerSheet(platforms: Array(platforms), selected: $selectedPlatform) {
                showPlatformPicker = false
            }
        }
    }

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
                        Circle()
                            .fill(Color.appProfit)
                            .frame(width: 8, height: 8)
                        Text("Live — \(AppFormatter.duration(elapsed / 3600))")
                            .font(.caption)
                            .foregroundColor(.appProfit)
                    }
                    .onReceive(timer) { _ in elapsed += 1 }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .listRowBackground(Color.appSurface)
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
                    Text(selectedPlatform?.displayName ?? "—")
                        .foregroundColor(.appGold)
                    Text("·")
                        .foregroundColor(.appSecondary)
                    Text(platformCurrency)
                        .foregroundColor(.appSecondary)
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
    }

    var gameDetailsSection: some View {
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
                Text(platformCurrency).font(.caption).foregroundColor(.appSecondary)
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
                Text(platformCurrency).font(.caption).foregroundColor(.appSecondary)
                TextField("0.00", text: $balanceAfter)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.appPrimary)
                    .frame(width: 100)
            }
            .listRowBackground(Color.appSurface)

            HStack {
                Text("Net Result")
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

    var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Text("Delete Session")
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.appLoss)
            }
            .listRowBackground(Color.appSurface)
        }
    }

    func loadFromSession() {
        guard !loaded else { return }
        loaded = true
        gameType = session.gameType ?? "No Limit Hold'em"
        blinds = session.blinds ?? ""
        tableSize = Int(session.tableSize)
        tables = Int(session.tables)
        startTime = session.startTime ?? Date()
        endTime = session.endTime ?? Date()
        balanceBefore = String(format: "%.2f", session.balanceBefore)
        balanceAfter = String(format: "%.2f", session.balanceAfter)
        exchangeRate = String(format: "%.4f", session.exchangeRateToBase)
        handsOverride = session.handsCount > 0 ? "\(session.handsCount)" : ""
        notes = session.notes ?? ""
        selectedPlatform = session.platform
        if session.isActive, let start = session.startTime {
            elapsed = Date().timeIntervalSince(start)
        }
    }

    func autoSave() {
        guard loaded else { return }
        session.gameType = gameType
        session.blinds = blinds
        session.tableSize = Int16(tableSize)
        session.tables = Int16(tables)
        session.startTime = startTime
        session.endTime = endTime
        session.duration = max(0, duration)
        session.balanceBefore = Double(balanceBefore) ?? 0
        session.balanceAfter = Double(balanceAfter) ?? 0
        session.exchangeRateToBase = Double(exchangeRate) ?? 1.0
        session.netProfitLoss = netPL
        session.netProfitLossBase = netPLBase
        session.handsCount = Int32(handsOverride) ?? 0
        session.notes = notes.isEmpty ? nil : notes
        session.platform = selectedPlatform
        try? viewContext.save()
    }
}
