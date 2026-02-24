import SwiftUI
import CoreData
import UIKit
import UniformTypeIdentifiers

// MARK: - Export/Import Data Structures

struct ExportData: Codable {
    let exportVersion: Int
    let exportDate: Date
    let baseCurrency: String
    let platforms: [PlatformExport]
    let liveSessions: [LiveSessionExport]
    let onlineSessions: [OnlineSessionExport]
    let deposits: [DepositExport]
    let withdrawals: [WithdrawalExport]
    let adjustments: [AdjustmentExport]
}

struct PlatformExport: Codable {
    let id: UUID
    let name: String
    let currency: String
    let currentBalance: Double
    let createdAt: Date?
}

struct LiveSessionExport: Codable {
    let id: UUID
    let startTime: Date?
    let endTime: Date?
    let duration: Double
    let gameType: String?
    let blinds: String?
    let smallBlind: Double
    let bigBlind: Double
    let straddle: Double
    let ante: Double
    let breakTime: Double
    let tableSize: Int16
    let location: String?
    let currency: String?
    let exchangeRateToBase: Double
    let exchangeRateBuyIn: Double
    let exchangeRateCashOut: Double
    let buyIn: Double
    let cashOut: Double
    let tips: Double
    let netProfitLoss: Double
    let netProfitLossBase: Double
    let handsCount: Int32
    let notes: String?
    let isVerified: Bool
}

struct OnlineSessionExport: Codable {
    let id: UUID
    let platformName: String?
    let startTime: Date?
    let endTime: Date?
    let duration: Double
    let gameType: String?
    let blinds: String?
    let smallBlind: Double
    let bigBlind: Double
    let straddle: Double
    let ante: Double
    let breakTime: Double
    let tableSize: Int16
    let tables: Int16
    let balanceBefore: Double
    let balanceAfter: Double
    let netProfitLoss: Double
    let netProfitLossBase: Double
    let exchangeRateToBase: Double
    let handsCount: Int32
    let notes: String?
    let isVerified: Bool
}

struct DepositExport: Codable {
    let id: UUID
    let platformName: String?
    let date: Date?
    let amountSent: Double
    let amountReceived: Double
    let isForeignExchange: Bool
    let effectiveExchangeRate: Double
    let processingFee: Double
    let method: String?
}

struct WithdrawalExport: Codable {
    let id: UUID
    let platformName: String?
    let date: Date?
    let amountRequested: Double
    let amountReceived: Double
    let isForeignExchange: Bool
    let effectiveExchangeRate: Double
    let processingFee: Double
    let method: String?
}

struct AdjustmentExport: Codable {
    let id: UUID
    let platformName: String?
    let name: String?
    let amount: Double
    let date: Date?
    let currency: String?
    let exchangeRateToBase: Double
    let amountBase: Double
    let isOnline: Bool
    let location: String?
    let notes: String?
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Document Picker

struct JSONDocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.json])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first { onPick(url) }
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("baseCurrency") private var baseCurrency = "CAD"
    @AppStorage("handsPerHourOnline") private var handsPerHourOnline = 85
    @AppStorage("handsPerHourLive") private var handsPerHourLive = 25
    @AppStorage("exchangeRateInputMode") private var exchangeRateInputMode = "direct"
    @AppStorage("defaultRateUSDToBase") private var defaultRateUSDToBase = 1.36
    @AppStorage("defaultRateEURToBase") private var defaultRateEURToBase = 1.47
    @AppStorage("defaultRateUSDToEUR") private var defaultRateUSDToEUR = 0.92
    @State private var showResetConfirmation = false

    // Export
    @State private var showShareSheet = false
    @State private var exportFileURL: URL? = nil
    @State private var exportError: String? = nil
    @State private var showExportError = false

    // Import
    @State private var showImportPicker = false
    @State private var showImportConfirm = false
    @State private var pendingImportURL: URL? = nil
    @State private var showImportSuccess = false
    @State private var importSummary = ""
    @State private var importError: String? = nil
    @State private var showImportError = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            Form {
                baseCurrencySection
                handsSection
                exchangeRateInputSection
                defaultRatesSection
                dataSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Reset All Data?", isPresented: $showResetConfirmation) {
            Button("Reset Everything", role: .destructive) { performReset() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(resetAlertMessage)
        }
        .alert("Export Error", isPresented: $showExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "Unknown error")
        }
        .alert("Import Data?", isPresented: $showImportConfirm) {
            Button("Import") { performImport() }
            Button("Cancel", role: .cancel) { pendingImportURL = nil }
        } message: {
            Text("Importing will add all records from the file to your existing data. Duplicate records will be skipped based on their ID. Continue?")
        }
        .alert("Import Complete", isPresented: $showImportSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importSummary)
        }
        .alert("Import Error", isPresented: $showImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "Unknown error")
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = exportFileURL {
                ShareSheet(items: [url])
            }
        }
        .sheet(isPresented: $showImportPicker) {
            JSONDocumentPicker { url in
                pendingImportURL = url
                showImportPicker = false
                showImportConfirm = true
            }
        }
    }

    var baseCurrencySection: some View {
        Section {
            HStack {
                Text("Base Currency")
                    .foregroundColor(.appPrimary)
                Spacer()
                Text(baseCurrency)
                    .foregroundColor(.appGold)
                    .fontWeight(.semibold)
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundColor(.appSecondary)
            }
            .listRowBackground(Color.appSurface)

            Text("Your base currency was set during onboarding and cannot be changed. All profits are reported in \(baseCurrency).")
                .font(.caption)
                .foregroundColor(.appSecondary)
                .listRowBackground(Color.appSurface)
        } header: {
            Text("Currency").foregroundColor(.appGold).textCase(nil)
        }
    }

    var handsSection: some View {
        Section {
            HStack {
                Text("Hands Per Hour (Online)")
                    .foregroundColor(.appPrimary)
                Spacer()
                Stepper("\(handsPerHourOnline)", value: $handsPerHourOnline, in: 10...200, step: 5)
                    .fixedSize()
                    .foregroundColor(.appGold)
            }
            .listRowBackground(Color.appSurface)

            HStack {
                Text("Hands Per Hour (Live)")
                    .foregroundColor(.appPrimary)
                Spacer()
                Stepper("\(handsPerHourLive)", value: $handsPerHourLive, in: 10...100, step: 5)
                    .fixedSize()
                    .foregroundColor(.appGold)
            }
            .listRowBackground(Color.appSurface)
        } header: {
            Text("Default Values").foregroundColor(.appGold).textCase(nil)
        }
    }

    var exchangeRateInputSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Picker("", selection: $exchangeRateInputMode) {
                    Text("Enter Rate Directly").tag("direct")
                    Text("Enter Amounts").tag("amounts")
                }
                .pickerStyle(.segmented)
                if exchangeRateInputMode == "direct" {
                    Text("You type the exchange rate (e.g. 1.36). We calculate the base currency equivalent.")
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                } else {
                    Text("You type how much you paid in both currencies. We calculate the effective rate.")
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                }
            }
            .listRowBackground(Color.appSurface)
        } header: {
            Text("Exchange Rate Input").foregroundColor(.appGold).textCase(nil)
        }
    }

    var defaultRatesSection: some View {
        Section {
            if baseCurrency != "USD" {
                HStack {
                    Text("USD → \(baseCurrency)")
                        .foregroundColor(.appPrimary)
                    Spacer()
                    TextField("1.36", value: $defaultRateUSDToBase, format: .number.precision(.fractionLength(4)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.appGold)
                        .frame(width: 80)
                }
                .listRowBackground(Color.appSurface)
            }
            if baseCurrency != "EUR" {
                HStack {
                    Text("EUR → \(baseCurrency)")
                        .foregroundColor(.appPrimary)
                    Spacer()
                    TextField("1.47", value: $defaultRateEURToBase, format: .number.precision(.fractionLength(4)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.appGold)
                        .frame(width: 80)
                }
                .listRowBackground(Color.appSurface)
            }
            if baseCurrency != "USD" && baseCurrency != "EUR" {
                HStack {
                    Text("USD → EUR")
                        .foregroundColor(.appPrimary)
                    Spacer()
                    TextField("0.92", value: $defaultRateUSDToEUR, format: .number.precision(.fractionLength(4)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.appGold)
                        .frame(width: 80)
                }
                .listRowBackground(Color.appSurface)
            }
            Text("These rates pre-fill when you log a foreign currency session. You can always override them per session.")
                .font(.caption)
                .foregroundColor(.appSecondary)
                .listRowBackground(Color.appSurface)
        } header: {
            Text("Default Exchange Rates").foregroundColor(.appGold).textCase(nil)
        }
    }

    var dataSection: some View {
        Section {
            Button {
                exportData()
            } label: {
                HStack {
                    Text("Export Data")
                        .foregroundColor(.appPrimary)
                    Spacer()
                    Image(systemName: "square.and.arrow.up")
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                }
            }
            .listRowBackground(Color.appSurface)

            Button {
                showImportPicker = true
            } label: {
                HStack {
                    Text("Import Data")
                        .foregroundColor(.appPrimary)
                    Spacer()
                    Image(systemName: "square.and.arrow.down")
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                }
            }
            .listRowBackground(Color.appSurface)

            Button {
                showResetConfirmation = true
            } label: {
                Text("Reset All Data")
                    .foregroundColor(.appLoss)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .listRowBackground(Color.appSurface)
        } header: {
            Text("Data").foregroundColor(.appGold).textCase(nil)
        }
    }

    var aboutSection: some View {
        Section {
            HStack {
                Text("App Name")
                    .foregroundColor(.appPrimary)
                Spacer()
                Text("Project Capital")
                    .foregroundColor(.appSecondary)
            }
            .listRowBackground(Color.appSurface)

            HStack {
                Text("Version")
                    .foregroundColor(.appPrimary)
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .foregroundColor(.appSecondary)
            }
            .listRowBackground(Color.appSurface)

            HStack {
                Text("Build")
                    .foregroundColor(.appPrimary)
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                    .foregroundColor(.appSecondary)
            }
            .listRowBackground(Color.appSurface)
        } header: {
            Text("About").foregroundColor(.appGold).textCase(nil)
        }
    }

    var resetAlertMessage: String {
        func countEntity(_ name: String) -> Int {
            let req = NSFetchRequest<NSFetchRequestResult>(entityName: name)
            return (try? viewContext.count(for: req)) ?? 0
        }
        let sessions = countEntity("OnlineCash") + countEntity("LiveCash")
        let platforms = countEntity("Platform")
        let deposits = countEntity("Deposit")
        let withdrawals = countEntity("Withdrawal")
        let adjustments = countEntity("Adjustment")

        var parts: [String] = []
        if sessions > 0 { parts.append("\(sessions) session\(sessions == 1 ? "" : "s")") }
        if platforms > 0 { parts.append("\(platforms) platform\(platforms == 1 ? "" : "s")") }
        if deposits > 0 { parts.append("\(deposits) deposit\(deposits == 1 ? "" : "s")") }
        if withdrawals > 0 { parts.append("\(withdrawals) withdrawal\(withdrawals == 1 ? "" : "s")") }
        if adjustments > 0 { parts.append("\(adjustments) adjustment\(adjustments == 1 ? "" : "s")") }

        let countText = parts.isEmpty ? "No data found." : "This will permanently delete \(parts.joined(separator: ", "))."
        return "\(countText) You will be returned to onboarding. This cannot be undone."
    }

    // MARK: - Export

    func exportData() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted

            let platformsData = try fetchExportPlatforms()
            let liveData = try fetchExportLiveSessions()
            let onlineData = try fetchExportOnlineSessions()
            let depositsData = try fetchExportDeposits()
            let withdrawalsData = try fetchExportWithdrawals()
            let adjustmentsData = try fetchExportAdjustments()

            let export = ExportData(
                exportVersion: 1,
                exportDate: Date(),
                baseCurrency: baseCurrency,
                platforms: platformsData,
                liveSessions: liveData,
                onlineSessions: onlineData,
                deposits: depositsData,
                withdrawals: withdrawalsData,
                adjustments: adjustmentsData
            )

            let jsonData = try encoder.encode(export)

            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            let fileName = "ProjectCapital_Export_\(df.string(from: Date())).json"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try jsonData.write(to: tempURL)

            exportFileURL = tempURL
            showShareSheet = true
        } catch {
            exportError = error.localizedDescription
            showExportError = true
        }
    }

    private func fetchExportPlatforms() throws -> [PlatformExport] {
        let req = NSFetchRequest<Platform>(entityName: "Platform")
        let results = try viewContext.fetch(req)
        return results.map {
            PlatformExport(id: $0.id ?? UUID(), name: $0.name ?? "", currency: $0.currency ?? "USD", currentBalance: $0.currentBalance, createdAt: $0.createdAt)
        }
    }

    private func fetchExportLiveSessions() throws -> [LiveSessionExport] {
        let req = NSFetchRequest<LiveCash>(entityName: "LiveCash")
        let results = try viewContext.fetch(req)
        return results.map {
            LiveSessionExport(id: $0.id ?? UUID(), startTime: $0.startTime, endTime: $0.endTime, duration: $0.duration, gameType: $0.gameType, blinds: $0.blinds, smallBlind: $0.smallBlind, bigBlind: $0.bigBlind, straddle: $0.straddle, ante: $0.ante, breakTime: $0.breakTime, tableSize: $0.tableSize, location: $0.location, currency: $0.currency, exchangeRateToBase: $0.exchangeRateToBase, exchangeRateBuyIn: $0.exchangeRateBuyIn, exchangeRateCashOut: $0.exchangeRateCashOut, buyIn: $0.buyIn, cashOut: $0.cashOut, tips: $0.tips, netProfitLoss: $0.netProfitLoss, netProfitLossBase: $0.netProfitLossBase, handsCount: $0.handsCount, notes: $0.notes, isVerified: $0.isVerified)
        }
    }

    private func fetchExportOnlineSessions() throws -> [OnlineSessionExport] {
        let req = NSFetchRequest<OnlineCash>(entityName: "OnlineCash")
        let results = try viewContext.fetch(req)
        return results.map {
            OnlineSessionExport(id: $0.id ?? UUID(), platformName: $0.platform?.name, startTime: $0.startTime, endTime: $0.endTime, duration: $0.duration, gameType: $0.gameType, blinds: $0.blinds, smallBlind: $0.smallBlind, bigBlind: $0.bigBlind, straddle: $0.straddle, ante: $0.ante, breakTime: $0.breakTime, tableSize: $0.tableSize, tables: $0.tables, balanceBefore: $0.balanceBefore, balanceAfter: $0.balanceAfter, netProfitLoss: $0.netProfitLoss, netProfitLossBase: $0.netProfitLossBase, exchangeRateToBase: $0.exchangeRateToBase, handsCount: $0.handsCount, notes: $0.notes, isVerified: $0.isVerified)
        }
    }

    private func fetchExportDeposits() throws -> [DepositExport] {
        let req = NSFetchRequest<Deposit>(entityName: "Deposit")
        let results = try viewContext.fetch(req)
        return results.map {
            DepositExport(id: $0.id ?? UUID(), platformName: $0.platform?.name, date: $0.date, amountSent: $0.amountSent, amountReceived: $0.amountReceived, isForeignExchange: $0.isForeignExchange, effectiveExchangeRate: $0.effectiveExchangeRate, processingFee: $0.processingFee, method: $0.method)
        }
    }

    private func fetchExportWithdrawals() throws -> [WithdrawalExport] {
        let req = NSFetchRequest<Withdrawal>(entityName: "Withdrawal")
        let results = try viewContext.fetch(req)
        return results.map {
            WithdrawalExport(id: $0.id ?? UUID(), platformName: $0.platform?.name, date: $0.date, amountRequested: $0.amountRequested, amountReceived: $0.amountReceived, isForeignExchange: $0.isForeignExchange, effectiveExchangeRate: $0.effectiveExchangeRate, processingFee: $0.processingFee, method: $0.method)
        }
    }

    private func fetchExportAdjustments() throws -> [AdjustmentExport] {
        let req = NSFetchRequest<Adjustment>(entityName: "Adjustment")
        let results = try viewContext.fetch(req)
        return results.map {
            AdjustmentExport(id: $0.id ?? UUID(), platformName: $0.platform?.name, name: $0.name, amount: $0.amount, date: $0.date, currency: $0.currency, exchangeRateToBase: $0.exchangeRateToBase, amountBase: $0.amountBase, isOnline: $0.isOnline, location: $0.location, notes: $0.notes)
        }
    }

    // MARK: - Import

    func performImport() {
        guard let url = pendingImportURL else { return }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let importData = try decoder.decode(ExportData.self, from: data)
            importRecords(from: importData)
        } catch {
            importError = "Failed to read file: \(error.localizedDescription)"
            showImportError = true
        }
        pendingImportURL = nil
    }

    private func importRecords(from data: ExportData) {
        var addedPlatforms = 0, addedLive = 0, addedOnline = 0
        var addedDeposits = 0, addedWithdrawals = 0, addedAdjustments = 0

        // Fetch existing IDs
        func existingIDs(entity: String) -> Set<UUID> {
            let req = NSFetchRequest<NSManagedObject>(entityName: entity)
            req.propertiesToFetch = ["id"]
            let results = (try? viewContext.fetch(req)) ?? []
            return Set(results.compactMap { ($0.value(forKey: "id") as? UUID) })
        }
        let existingPlatformIDs = existingIDs(entity: "Platform") as Set<UUID>
        let existingLiveIDs = existingIDs(entity: "LiveCash") as Set<UUID>
        let existingOnlineIDs = existingIDs(entity: "OnlineCash") as Set<UUID>
        let existingDepositIDs = existingIDs(entity: "Deposit") as Set<UUID>
        let existingWithdrawalIDs = existingIDs(entity: "Withdrawal") as Set<UUID>
        let existingAdjustmentIDs = existingIDs(entity: "Adjustment") as Set<UUID>

        // Platform name → object map (for linking)
        var platformByName: [String: Platform] = [:]
        let platformReq = NSFetchRequest<Platform>(entityName: "Platform")
        let existingPlatforms = (try? viewContext.fetch(platformReq)) ?? []
        for p in existingPlatforms { if let n = p.name { platformByName[n] = p } }

        // Import platforms
        for p in data.platforms {
            if existingPlatformIDs.contains(p.id) { continue }
            if let existing = platformByName[p.name] {
                platformByName[p.name] = existing
                continue
            }
            let platform = Platform(context: viewContext)
            platform.id = p.id
            platform.name = p.name
            platform.currency = p.currency
            platform.currentBalance = p.currentBalance
            platform.createdAt = p.createdAt
            platformByName[p.name] = platform
            addedPlatforms += 1
        }

        // Import live sessions
        for s in data.liveSessions {
            if existingLiveIDs.contains(s.id) { continue }
            let session = LiveCash(context: viewContext)
            session.id = s.id
            session.startTime = s.startTime
            session.endTime = s.endTime
            session.duration = s.duration
            session.gameType = s.gameType
            session.blinds = s.blinds
            session.smallBlind = s.smallBlind
            session.bigBlind = s.bigBlind
            session.straddle = s.straddle
            session.ante = s.ante
            session.breakTime = s.breakTime
            session.tableSize = s.tableSize
            session.location = s.location
            session.currency = s.currency
            session.exchangeRateToBase = s.exchangeRateToBase
            session.exchangeRateBuyIn = s.exchangeRateBuyIn
            session.exchangeRateCashOut = s.exchangeRateCashOut
            session.buyIn = s.buyIn
            session.cashOut = s.cashOut
            session.tips = s.tips
            session.netProfitLoss = s.netProfitLoss
            session.netProfitLossBase = s.netProfitLossBase
            session.handsCount = s.handsCount
            session.notes = s.notes
            session.isVerified = s.isVerified
            addedLive += 1
        }

        // Import online sessions
        for s in data.onlineSessions {
            if existingOnlineIDs.contains(s.id) { continue }
            let session = OnlineCash(context: viewContext)
            session.id = s.id
            session.platform = s.platformName.flatMap { platformByName[$0] }
            session.startTime = s.startTime
            session.endTime = s.endTime
            session.duration = s.duration
            session.gameType = s.gameType
            session.blinds = s.blinds
            session.smallBlind = s.smallBlind
            session.bigBlind = s.bigBlind
            session.straddle = s.straddle
            session.ante = s.ante
            session.breakTime = s.breakTime
            session.tableSize = s.tableSize
            session.tables = s.tables
            session.balanceBefore = s.balanceBefore
            session.balanceAfter = s.balanceAfter
            session.netProfitLoss = s.netProfitLoss
            session.netProfitLossBase = s.netProfitLossBase
            session.exchangeRateToBase = s.exchangeRateToBase
            session.handsCount = s.handsCount
            session.notes = s.notes
            session.isVerified = s.isVerified
            addedOnline += 1
        }

        // Import deposits
        for d in data.deposits {
            if existingDepositIDs.contains(d.id) { continue }
            let deposit = Deposit(context: viewContext)
            deposit.id = d.id
            deposit.platform = d.platformName.flatMap { platformByName[$0] }
            deposit.date = d.date
            deposit.amountSent = d.amountSent
            deposit.amountReceived = d.amountReceived
            deposit.isForeignExchange = d.isForeignExchange
            deposit.effectiveExchangeRate = d.effectiveExchangeRate
            deposit.processingFee = d.processingFee
            deposit.method = d.method
            addedDeposits += 1
        }

        // Import withdrawals
        for w in data.withdrawals {
            if existingWithdrawalIDs.contains(w.id) { continue }
            let withdrawal = Withdrawal(context: viewContext)
            withdrawal.id = w.id
            withdrawal.platform = w.platformName.flatMap { platformByName[$0] }
            withdrawal.date = w.date
            withdrawal.amountRequested = w.amountRequested
            withdrawal.amountReceived = w.amountReceived
            withdrawal.isForeignExchange = w.isForeignExchange
            withdrawal.effectiveExchangeRate = w.effectiveExchangeRate
            withdrawal.processingFee = w.processingFee
            withdrawal.method = w.method
            addedWithdrawals += 1
        }

        // Import adjustments
        for a in data.adjustments {
            if existingAdjustmentIDs.contains(a.id) { continue }
            let adjustment = Adjustment(context: viewContext)
            adjustment.id = a.id
            adjustment.platform = a.platformName.flatMap { platformByName[$0] }
            adjustment.name = a.name
            adjustment.amount = a.amount
            adjustment.date = a.date
            adjustment.currency = a.currency
            adjustment.exchangeRateToBase = a.exchangeRateToBase
            adjustment.amountBase = a.amountBase
            adjustment.isOnline = a.isOnline
            adjustment.location = a.location
            adjustment.notes = a.notes
            addedAdjustments += 1
        }

        do {
            try viewContext.save()
            let total = addedLive + addedOnline
            var parts: [String] = []
            if total > 0 { parts.append("\(total) session\(total == 1 ? "" : "s")") }
            if addedPlatforms > 0 { parts.append("\(addedPlatforms) platform\(addedPlatforms == 1 ? "" : "s")") }
            if addedDeposits > 0 { parts.append("\(addedDeposits) deposit\(addedDeposits == 1 ? "" : "s")") }
            if addedWithdrawals > 0 { parts.append("\(addedWithdrawals) withdrawal\(addedWithdrawals == 1 ? "" : "s")") }
            if addedAdjustments > 0 { parts.append("\(addedAdjustments) adjustment\(addedAdjustments == 1 ? "" : "s")") }
            importSummary = parts.isEmpty ? "No new records were added (all duplicates skipped)." : "\(parts.joined(separator: ", ")) were added."
            showImportSuccess = true
        } catch {
            importError = "Failed to save imported data: \(error.localizedDescription)"
            showImportError = true
        }
    }

    // MARK: - Reset

    func performReset() {
        let entityNames = ["OnlineCash", "LiveCash", "Platform", "Deposit", "Withdrawal", "Adjustment"]
        for name in entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: name)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            let _ = try? viewContext.execute(deleteRequest)
        }
        viewContext.refreshAllObjects()
        try? viewContext.save()

        let defaults = UserDefaults.standard
        for key in ["baseCurrency", "handsPerHourOnline", "handsPerHourLive",
                    "exchangeRateInputMode", "defaultRateUSDToBase", "defaultRateEURToBase",
                    "defaultRateUSDToEUR", "showAdjustmentsInStats"] {
            defaults.removeObject(forKey: key)
        }

        hasCompletedOnboarding = false
    }
}

#Preview {
    SettingsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .preferredColorScheme(.dark)
}
