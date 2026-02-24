import SwiftUI
import CoreData
import Combine
import UIKit

struct OnlineSessionDetailView: View {
    @ObservedObject var session: OnlineCash
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("baseCurrency") private var baseCurrency = "CAD"

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Platform.name, ascending: true)],
        animation: .default
    ) private var platforms: FetchedResults<Platform>

    @State private var showDeleteAlert = false
    @State private var showVerifyAlert = false
    @State private var showTimeAlert = false
    @Environment(\.dismiss) private var dismiss

    @State private var gameType = ""
    @State private var smallBlind = ""
    @State private var bigBlind = ""
    @State private var straddle = ""
    @State private var ante = ""
    @State private var breakTimeStr = ""
    @State private var tableSize = 6
    @State private var tables = 1
    @State private var startTime = Date()
    @State private var endTime = Date()
    @State private var prevStartTime = Date()
    @State private var prevEndTime = Date()
    @State private var balanceBefore = ""
    @State private var balanceAfter = ""
    @State private var handsOverride = ""
    @State private var notes = ""
    @State private var selectedPlatform: Platform? = nil
    @State private var showPlatformPicker = false
    @State private var loaded = false
    @State private var elapsed: TimeInterval = 0
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var breakTimeMinutes: Double { Double(breakTimeStr) ?? 0 }
    var duration: Double { max(0, endTime.timeIntervalSince(startTime) / 3600.0 - breakTimeMinutes / 60.0) }
    var netPL: Double { (Double(balanceAfter) ?? 0) - (Double(balanceBefore) ?? 0) }
    var netPLBase: Double { isSameCurrency ? netPL : netPL * (selectedPlatform?.latestFXConversionRate ?? 1.0) }
    var platformCurrency: String { selectedPlatform?.displayCurrency ?? session.platformCurrency }
    var isSameCurrency: Bool { platformCurrency == baseCurrency }
    var sbDouble: Double { Double(smallBlind) ?? 0 }
    var bbDouble: Double { Double(bigBlind) ?? 0 }
    var estimatedHands: Int {
        let s = UserSettings.shared
        return Int(duration * Double(s.handsPerHourOnline) * Double(tables))
    }
    var effectiveHands: Int {
        if let manual = Int(handsOverride), manual > 0 { return manual }
        return estimatedHands
    }
    var isVerified: Bool { session.isVerified }
    var canVerify: Bool {
        selectedPlatform != nil &&
        !gameType.isEmpty &&
        sbDouble > 0 && bbDouble > 0
    }

    var body: some View {
        mainContentWithAlerts
    }

    private var mainZStack: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            if isVerified {
                RoundedRectangle(cornerRadius: 0)
                    .stroke(Color.appGold.opacity(0.4), lineWidth: 1)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .zIndex(999)
            }

            VStack(spacing: 0) {
                Form {
                    headerSection
                    platformSection
                    gameDetailsSection
                    timingSection
                    balanceSection
                    handsSection
                    notesSection
                    if !isVerified {
                        deleteSection
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.appBackground)
                .selectAllOnFocus()

                verifyBar
            }
        }
    }

    private var mainContentWithOnChange: some View {
        mainZStack
            .navigationTitle("Online Session")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { loadFromSession() }
            .onChange(of: gameType) { _, _ in autoSave() }
            .onChange(of: smallBlind) { _, _ in autoSave() }
            .onChange(of: bigBlind) { _, _ in autoSave() }
            .onChange(of: straddle) { _, _ in autoSave() }
            .onChange(of: ante) { _, _ in autoSave() }
            .onChange(of: breakTimeStr) { _, _ in autoSave() }
            .onChange(of: tableSize) { _, _ in autoSave() }
            .onChange(of: tables) { _, _ in autoSave() }
            .onChange(of: balanceBefore) { _, _ in autoSave() }
            .onChange(of: balanceAfter) { _, _ in autoSave() }
    }

    private var mainContentWithMoreOnChange: some View {
        mainContentWithOnChange
            .onChange(of: handsOverride) { _, _ in autoSave() }
            .onChange(of: notes) { _, _ in autoSave() }
            .onChange(of: selectedPlatform) { _, _ in autoSave() }
            .onChange(of: startTime) { oldVal, newVal in
                if oldVal.timeIntervalSince(newVal) > 20 * 3600 {
                    startTime = Calendar.current.date(byAdding: .day, value: 1, to: newVal) ?? newVal
                    return
                }
                if endTime <= startTime { showTimeAlert = true; startTime = prevStartTime }
                else { prevStartTime = startTime; autoSave() }
            }
            .onChange(of: endTime) { oldVal, newVal in
                if oldVal.timeIntervalSince(newVal) > 20 * 3600 {
                    endTime = Calendar.current.date(byAdding: .day, value: 1, to: newVal) ?? newVal
                    return
                }
                if endTime <= startTime { showTimeAlert = true; endTime = prevEndTime }
                else { prevEndTime = endTime; autoSave() }
            }
    }

    private var mainContentWithAlerts: some View {
        mainContentWithMoreOnChange
            .alert("Invalid Time Range", isPresented: $showTimeAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("End time must be after start time.")
            }
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
            .alert("Verify Session?", isPresented: $showVerifyAlert) {
                Button("Verify") { verifySession() }
                    .foregroundStyle(Color.appGold)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Verify this session? Balance Before and Balance After will be permanently locked and cannot be changed.")
            }
            .sheet(isPresented: $showPlatformPicker) {
                PlatformPickerSheet(platforms: Array(platforms), selected: $selectedPlatform) {
                    showPlatformPicker = false
                }
            }
    }

    // MARK: - Bottom Bar

    var verifyBar: some View {
        Group {
            if session.endTime != nil {
                if isVerified {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill").foregroundColor(.appGold).font(.subheadline)
                        Text("Verified").font(.subheadline).fontWeight(.medium).foregroundColor(.appGold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.appBackground)
                } else {
                    Button {
                        if canVerify { showVerifyAlert = true }
                    } label: {
                        Text("Verify Session")
                            .font(.headline).fontWeight(.semibold)
                            .foregroundColor(canVerify ? .black : .appGold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(canVerify ? Color.appGold : Color.clear)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appGold, lineWidth: canVerify ? 0 : 1.5))
                            .cornerRadius(12)
                            .opacity(canVerify ? 1.0 : 0.5)
                    }
                    .disabled(!canVerify)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.appBackground)
                }
            }
        }
    }

    // MARK: - Header

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
                .font(.subheadline).foregroundColor(.appSecondary)
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

    // MARK: - Platform (always editable)

    var platformSection: some View {
        Section {
            Button {
                showPlatformPicker = true
            } label: {
                HStack {
                    Text("Platform").foregroundColor(.appPrimary)
                    Spacer()
                    Text(selectedPlatform?.displayName ?? "—").foregroundColor(.appGold)
                    Text("·").foregroundColor(.appSecondary)
                    Text(platformCurrency).foregroundColor(.appSecondary)
                    Image(systemName: "chevron.right").font(.caption).foregroundColor(.appSecondary)
                }
            }
            .listRowBackground(Color.appSurface)

        } header: {
            Text("Platform").foregroundColor(.appGold).textCase(nil)
        }
    }

    // MARK: - Game Details (always editable)

    var gameDetailsSection: some View {
        Section {
            Picker("Game Type", selection: $gameType) {
                ForEach(gameTypes, id: \.self) { Text($0) }
            }
            .foregroundColor(.appPrimary)
            .listRowBackground(Color.appSurface)

            HStack(spacing: 12) {
                blindField(label: "SB", text: $smallBlind)
                blindField(label: "BB", text: $bigBlind)
                blindField(label: "Straddle", text: $straddle)
                blindField(label: "Ante", text: $ante)
            }
            .listRowBackground(Color.appSurface)

            Stepper("Table Size: \(tableSize)", value: $tableSize, in: 2...10)
                .foregroundColor(.appPrimary).listRowBackground(Color.appSurface)

            Stepper("Tables: \(tables)", value: $tables, in: 1...10)
                .foregroundColor(.appPrimary).listRowBackground(Color.appSurface)
        } header: {
            Text("Game Details").foregroundColor(.appGold).textCase(nil)
        }
    }

    @ViewBuilder
    func blindField(label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption2).foregroundColor(.appSecondary)
            TextField("0", text: text)
                .keyboardType(.decimalPad).foregroundColor(.appGold)
                .multilineTextAlignment(.center).frame(maxWidth: .infinity)
                .padding(.vertical, 6).background(Color.appSurface2).cornerRadius(6)
        }
    }

    // MARK: - Timing (always editable)

    var timingSection: some View {
        Section {
            DatePicker("Start", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                .foregroundColor(.appPrimary).tint(.appGold)
                .listRowBackground(Color.appSurface)
            DatePicker("End", selection: $endTime, displayedComponents: [.date, .hourAndMinute])
                .foregroundColor(.appPrimary).tint(.appGold)
                .listRowBackground(Color.appSurface)
            HStack {
                Text("Break (min)").foregroundColor(.appPrimary)
                Spacer()
                TextField("0", text: $breakTimeStr)
                    .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                    .foregroundColor(.appGold).frame(width: 80)
            }
            .listRowBackground(Color.appSurface)
            HStack {
                Text("Duration").foregroundColor(.appPrimary)
                Spacer()
                Text(AppFormatter.duration(duration)).foregroundColor(.appSecondary)
            }
            .listRowBackground(Color.appSurface)
        } header: {
            Text("Timing").foregroundColor(.appGold).textCase(nil)
        }
    }

    // MARK: - Balance

    var balanceSection: some View {
        Section {
            if isVerified {
                lockedRow(label: "Balance Before", value: "\(platformCurrency) \(String(format: "%.2f", session.balanceBefore))")
            } else {
                HStack {
                    Text("Balance Before").foregroundColor(.appPrimary)
                    Spacer()
                    Text(platformCurrency).font(.caption).foregroundColor(.appSecondary)
                    TextField("0", text: $balanceBefore)
                        .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        .foregroundColor(.appPrimary).frame(width: 100)
                }
                .listRowBackground(Color.appSurface)
            }

            if isVerified {
                lockedRow(label: "Balance After", value: "\(platformCurrency) \(String(format: "%.2f", session.balanceAfter))")
            } else {
                HStack {
                    Text("Balance After").foregroundColor(.appPrimary)
                    Spacer()
                    Text(platformCurrency).font(.caption).foregroundColor(.appSecondary)
                    TextField("0", text: $balanceAfter)
                        .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        .foregroundColor(.appPrimary).frame(width: 100)
                }
                .listRowBackground(Color.appSurface)
            }

            HStack {
                Text("Net Result").foregroundColor(.appPrimary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(AppFormatter.currencySigned(netPL, code: platformCurrency))
                        .fontWeight(.semibold).foregroundColor(netPL.profitColor)
                    if !isSameCurrency {
                        Text(AppFormatter.currencySigned(netPLBase, code: baseCurrency))
                            .font(.caption).foregroundColor(netPLBase.profitColor)
                    }
                }
            }
            .listRowBackground(Color.appSurface)
        } header: {
            Text("Balance").foregroundColor(.appGold).textCase(nil)
        }
    }

    // MARK: - Hands (always editable)

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

    // MARK: - Notes (always editable)

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

    // MARK: - Delete

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

    // MARK: - Locked Field Row

    @ViewBuilder
    func lockedRow(label: String, value: String) -> some View {
        Button { triggerLockHaptic() } label: {
            HStack {
                Text(label).foregroundColor(.appPrimary)
                Spacer()
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundColor(.appGold)
                    .shadow(color: Color(hex: "#C9B47A"), radius: 6, x: 0, y: 0)
                Text(value)
                    .foregroundColor(.appSecondary)
                    .shadow(color: Color(hex: "#C9B47A"), radius: 6, x: 0, y: 0)
            }
        }
        .listRowBackground(
            Color.appSurface
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.appGold.opacity(0.7), lineWidth: 2.5)
                )
        )
    }

    // MARK: - Helpers

    func triggerLockHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.impactOccurred()
    }

    func verifySession() {
        session.isVerified = true
        autoSave()
    }

    func loadFromSession() {
        guard !loaded else { return }
        loaded = true
        gameType = session.gameType ?? "No Limit Hold'em"

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
        tableSize = Int(session.tableSize)
        tables = Int(session.tables)
        startTime = session.startTime ?? Date()
        endTime = session.endTime ?? Date()
        prevStartTime = startTime
        prevEndTime = endTime
        balanceBefore = String(format: "%.2f", session.balanceBefore)
        balanceAfter = String(format: "%.2f", session.balanceAfter)
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
        session.smallBlind = sbDouble
        session.bigBlind = bbDouble
        session.straddle = Double(straddle) ?? 0
        session.ante = Double(ante) ?? 0
        session.blinds = "\(AppFormatter.blindValue(sbDouble))/\(AppFormatter.blindValue(bbDouble))"
        session.tableSize = Int16(tableSize)
        session.tables = Int16(tables)
        session.breakTime = breakTimeMinutes
        session.startTime = startTime
        session.endTime = endTime
        session.duration = duration
        if !isVerified {
            session.balanceBefore = Double(balanceBefore) ?? 0
            session.balanceAfter = Double(balanceAfter) ?? 0
        }
        session.exchangeRateToBase = selectedPlatform?.latestFXConversionRate ?? 1.0
        session.netProfitLoss = netPL
        session.netProfitLossBase = netPLBase
        session.handsCount = Int32(handsOverride) ?? 0
        session.notes = notes.isEmpty ? nil : notes
        session.platform = selectedPlatform
        try? viewContext.save()
    }
}
