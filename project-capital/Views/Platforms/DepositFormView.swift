import SwiftUI
import CoreData

struct DepositFormView: View {
    let platform: Platform
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("baseCurrency") private var baseCurrency = "CAD"

    @State private var amountSent = ""
    @State private var amountReceived = ""
    @State private var effectiveRateStr = ""
    @State private var date = Date()
    @State private var isForeignExchange = true
    @State private var method = "E-Transfer"

    @State private var showNegativeFeeWarning = false
    @State private var showLockConfirmation = false
    @State private var showProfitAlert = false

    var isSameCurrency: Bool { platform.displayCurrency == baseCurrency }

    // FX ON: effectiveRate = amountReceived(platform) / amountSent(base) — platform per base unit
    var computedEffectiveRate: Double {
        let s = Double(amountSent) ?? 0
        let r = Double(amountReceived) ?? 0
        guard s > 0, r > 0 else { return 0 }
        return r / s
    }

    // Processing fee (positive = loss, only for non-FX transactions)
    var processingFee: Double {
        (Double(amountSent) ?? 0) - (Double(amountReceived) ?? 0)
    }

    var isValid: Bool {
        (Double(amountSent) ?? 0) > 0 && (Double(amountReceived) ?? 0) > 0
    }

    // Block if received > sent in same-unit contexts (same currency or non-FX)
    var isProfitTransaction: Bool {
        let sent = Double(amountSent) ?? 0
        let received = Double(amountReceived) ?? 0
        guard sent > 0, received > 0 else { return false }
        return (isSameCurrency || !isForeignExchange) && received > sent
    }

    var sentLabel: String {
        if isSameCurrency { return "Amount Sent (\(baseCurrency))" }
        return isForeignExchange ? "Amount Sent (\(baseCurrency))" : "Amount Sent (\(platform.displayCurrency))"
    }

    var receivedLabel: String {
        isForeignExchange ? "Amount Received (\(platform.displayCurrency))" : "Amount Received (\(platform.displayCurrency))"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                Form {
                    amountsSection
                    detailsSection
                    saveSection
                }
                .scrollContentBackground(.hidden)
                .background(Color.appBackground)
            }
            .navigationTitle("Record Deposit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.appSecondary)
                }
            }
        }
        .alert("Invalid Transaction", isPresented: $showProfitAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You cannot receive more than you sent.")
        }
        .alert("Negative Processing Fee", isPresented: $showNegativeFeeWarning) {
            Button("Save Anyway") { showLockConfirmation = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("A negative processing fee means you gained money on this transaction. Please verify this is correct.")
        }
        .alert("Permanently Save Deposit?", isPresented: $showLockConfirmation) {
            Button("Confirm") { performSave() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deposit will be permanently saved and cannot be edited or deleted after confirmation. Are you sure?")
        }
    }

    var amountsSection: some View {
        Section {
            // Amount Sent
            HStack {
                Text(sentLabel).foregroundColor(.appPrimary)
                Spacer()
                TextField("0.00", text: $amountSent)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.appPrimary)
                    .frame(width: 120)
                    .onChange(of: amountSent) { _, _ in recalcRate() }
            }
            .listRowBackground(Color.appSurface)

            // Amount Received
            HStack {
                Text(receivedLabel).foregroundColor(.appPrimary)
                Spacer()
                TextField("0.00", text: $amountReceived)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.appPrimary)
                    .frame(width: 120)
                    .onChange(of: amountReceived) { _, _ in recalcRate() }
            }
            .listRowBackground(Color.appSurface)

            if !isSameCurrency {
                Toggle(isOn: $isForeignExchange) {
                    Text("Foreign Exchange").foregroundColor(.appPrimary)
                }
                .tint(.appGold)
                .listRowBackground(Color.appSurface)

                if isForeignExchange {
                    // Effective Rate (auto-calc, editable)
                    HStack {
                        Text("Effective Rate").foregroundColor(.appSecondary)
                        Spacer()
                        TextField("0.0000", text: $effectiveRateStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.appGold)
                            .frame(width: 90)
                        Text("\(platform.displayCurrency)/\(baseCurrency)")
                            .font(.caption).foregroundColor(.appSecondary)
                    }
                    .listRowBackground(Color.appSurface)
                } else {
                    // Processing Fee (positive = loss; warn if negative)
                    HStack {
                        Text("Processing Fee (\(platform.displayCurrency))")
                            .foregroundColor(.appSecondary)
                        Spacer()
                        Text(String(format: "%.2f", max(0, processingFee)))
                            .foregroundColor(.appNeutral)
                    }
                    .listRowBackground(Color.appSurface)
                }
            } else if processingFee != 0 {
                HStack {
                    Text("Processing Fee (\(baseCurrency))").foregroundColor(.appSecondary)
                    Spacer()
                    Text(String(format: "%.2f", abs(processingFee))).foregroundColor(.appNeutral)
                }
                .listRowBackground(Color.appSurface)
            }
        } header: {
            Text("Amounts").foregroundColor(.appGold).textCase(nil)
        }
    }

    var detailsSection: some View {
        Section {
            DatePicker("Date", selection: $date, displayedComponents: .date)
                .foregroundColor(.appPrimary).tint(.appGold)
                .listRowBackground(Color.appSurface)

            Picker("Method", selection: $method) {
                ForEach(depositMethods, id: \.self) { Text($0) }
            }
            .foregroundColor(.appPrimary).tint(.appGold)
            .listRowBackground(Color.appSurface)
        } header: {
            Text("Details").foregroundColor(.appGold).textCase(nil)
        }
    }

    var saveSection: some View {
        Section {
            Button {
                if isProfitTransaction {
                    showProfitAlert = true
                } else if !isSameCurrency && !isForeignExchange && processingFee < 0 {
                    showNegativeFeeWarning = true
                } else {
                    showLockConfirmation = true
                }
            } label: {
                Text("Save Deposit")
                    .font(.headline)
                    .foregroundColor(isValid ? .black : .appSecondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 4)
            }
            .disabled(!isValid)
            .listRowBackground(isValid ? Color.appGold : Color.appSurface2)
        }
    }

    func recalcRate() {
        let s = Double(amountSent) ?? 0
        let r = Double(amountReceived) ?? 0
        if s > 0, r > 0 { effectiveRateStr = String(format: "%.4f", r / s) }
    }

    func performSave() {
        let deposit = Deposit(context: viewContext)
        deposit.id = UUID()
        deposit.date = date
        deposit.amountSent = Double(amountSent) ?? 0
        deposit.amountReceived = Double(amountReceived) ?? 0
        deposit.method = method
        deposit.platform = platform

        if isSameCurrency {
            deposit.isForeignExchange = false
            deposit.effectiveExchangeRate = 0
            deposit.processingFee = processingFee
        } else if isForeignExchange {
            deposit.isForeignExchange = true
            deposit.effectiveExchangeRate = Double(effectiveRateStr) ?? computedEffectiveRate
            deposit.processingFee = 0
        } else {
            deposit.isForeignExchange = false
            deposit.effectiveExchangeRate = 0
            deposit.processingFee = processingFee
        }

        // Platform balance increases by amount received (always in platform currency)
        platform.currentBalance += deposit.amountReceived

        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Save deposit error: \(error)")
        }
    }
}
