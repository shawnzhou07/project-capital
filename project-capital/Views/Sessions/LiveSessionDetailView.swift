import SwiftUI
import CoreData
import Combine

struct LiveSessionDetailView: View {
    @ObservedObject var session: LiveCash
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("baseCurrency") private var baseCurrency = "CAD"

    @State private var showDeleteAlert = false
    @Environment(\.dismiss) private var dismiss

    @State private var location = ""
    @State private var currency = "CAD"
    @State private var exchangeRate = "1.0000"
    @State private var gameType = "No Limit Hold'em"
    @State private var blinds = ""
    @State private var tableSize = 9
    @State private var startTime = Date()
    @State private var endTime = Date()
    @State private var buyIn = ""
    @State private var cashOut = ""
    @State private var tips = "0"
    @State private var handsOverride = ""
    @State private var notes = ""
    @State private var loaded = false
    @State private var elapsed: TimeInterval = 0
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var duration: Double { endTime.timeIntervalSince(startTime) / 3600.0 }
    var netPL: Double { (Double(cashOut) ?? 0) - (Double(buyIn) ?? 0) - (Double(tips) ?? 0) }
    var netPLBase: Double { netPL * (Double(exchangeRate) ?? 1.0) }
    var isSameCurrency: Bool { currency == baseCurrency }
    var estimatedHands: Int { Int(max(0, duration) * Double(UserSettings.shared.handsPerHourLive)) }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            Form {
                headerSection
                locationSection
                gameDetailsSection
                timingSection
                financialsSection
                handsSection
                notesSection
                deleteSection
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
        }
        .navigationTitle("Live Session")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadFromSession() }
        .onChange(of: location) { _, _ in autoSave() }
        .onChange(of: currency) { _, _ in autoSave() }
        .onChange(of: exchangeRate) { _, _ in autoSave() }
        .onChange(of: gameType) { _, _ in autoSave() }
        .onChange(of: blinds) { _, _ in autoSave() }
        .onChange(of: tableSize) { _, _ in autoSave() }
        .onChange(of: startTime) { _, _ in autoSave() }
        .onChange(of: endTime) { _, _ in autoSave() }
        .onChange(of: buyIn) { _, _ in autoSave() }
        .onChange(of: cashOut) { _, _ in autoSave() }
        .onChange(of: tips) { _, _ in autoSave() }
        .onChange(of: handsOverride) { _, _ in autoSave() }
        .onChange(of: notes) { _, _ in autoSave() }
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
                        Circle().fill(Color.appProfit).frame(width: 8, height: 8)
                        Text("Live — \(AppFormatter.duration(elapsed / 3600))")
                            .font(.caption).foregroundColor(.appProfit)
                    }
                    .onReceive(timer) { _ in elapsed += 1 }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .listRowBackground(Color.appSurface)
    }

    var locationSection: some View {
        Section {
            HStack {
                Text("Location")
                    .foregroundColor(.appPrimary)
                Spacer()
                TextField("Casino / location", text: $location)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.appGold)
            }
            .listRowBackground(Color.appSurface)

            Picker("Currency", selection: $currency) {
                ForEach(supportedCurrencies, id: \.self) { Text($0).tag($0) }
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
        } header: {
            Text("Game Details").foregroundColor(.appGold).textCase(nil)
        }
    }

    var timingSection: some View {
        Section {
            DatePicker("Start Time", selection: $startTime)
                .foregroundColor(.appPrimary).tint(.appGold)
                .listRowBackground(Color.appSurface)
            DatePicker("End Time", selection: $endTime)
                .foregroundColor(.appPrimary).tint(.appGold)
                .listRowBackground(Color.appSurface)
            HStack {
                Text("Duration").foregroundColor(.appPrimary)
                Spacer()
                Text(AppFormatter.duration(max(0, duration))).foregroundColor(.appSecondary)
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
                TextField("0.00", text: $buyIn)
                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    .foregroundColor(.appPrimary).frame(width: 100)
            }
            .listRowBackground(Color.appSurface)

            HStack {
                Text("Cash Out").foregroundColor(.appPrimary)
                Spacer()
                Text(currency).font(.caption).foregroundColor(.appSecondary)
                TextField("0.00", text: $cashOut)
                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    .foregroundColor(.appPrimary).frame(width: 100)
            }
            .listRowBackground(Color.appSurface)

            HStack {
                Text("Tips").foregroundColor(.appPrimary)
                Spacer()
                Text(currency).font(.caption).foregroundColor(.appSecondary)
                TextField("0.00", text: $tips)
                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    .foregroundColor(.appPrimary).frame(width: 100)
            }
            .listRowBackground(Color.appSurface)

            HStack {
                Text("Net P&L").foregroundColor(.appPrimary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(AppFormatter.currencySigned(netPL, code: currency))
                        .fontWeight(.semibold).foregroundColor(netPL.profitColor)
                    if !isSameCurrency {
                        Text(AppFormatter.currencySigned(netPLBase, code: baseCurrency))
                            .font(.caption).foregroundColor(netPLBase.profitColor)
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
                Text("Hands Played").foregroundColor(.appPrimary)
                Spacer()
                TextField("Auto (\(estimatedHands) est.)", text: $handsOverride)
                    .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                    .foregroundColor(.appGold).frame(width: 140)
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
        } header: {
            Text("Notes").foregroundColor(.appGold).textCase(nil)
        }
    }

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

    func loadFromSession() {
        guard !loaded else { return }
        loaded = true
        location = session.location ?? ""
        currency = session.currency ?? baseCurrency
        exchangeRate = String(format: "%.4f", session.exchangeRateToBase)
        gameType = session.gameType ?? "No Limit Hold'em"
        blinds = session.blinds ?? ""
        tableSize = Int(session.tableSize)
        startTime = session.startTime ?? Date()
        endTime = session.endTime ?? Date()
        buyIn = String(format: "%.2f", session.buyIn)
        cashOut = String(format: "%.2f", session.cashOut)
        tips = String(format: "%.2f", session.tips)
        handsOverride = session.handsCount > 0 ? "\(session.handsCount)" : ""
        notes = session.notes ?? ""
        if session.isActive, let start = session.startTime {
            elapsed = Date().timeIntervalSince(start)
        }
    }

    func autoSave() {
        guard loaded else { return }
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
        try? viewContext.save()
    }
}
