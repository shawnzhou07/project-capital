import SwiftUI
import CoreData

struct WithdrawalFormView: View {
    let platform: Platform
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("baseCurrency") private var baseCurrency = "CAD"

    @State private var amountRequested = ""
    @State private var amountReceived = ""
    @State private var effectiveRateStr = ""
    @State private var date = Date()
    @State private var isForeignExchange = true
    @State private var method = "E-Transfer"

    @State private var showNegativeFeeWarning = false
    @State private var showLockConfirmation = false
    @State private var showProfitAlert = false

    var isSameCurrency: Bool { platform.displayCurrency == baseCurrency }

    // FX ON: effectiveRate = amountReceived(base) / amountRequested(platform) — base per platform unit
    var computedEffectiveRate: Double {
        let req = Double(amountRequested) ?? 0
        let rec = Double(amountReceived) ?? 0
        guard req > 0, rec > 0 else { return 0 }
        return rec / req
    }

    // Processing fee (positive = loss)
    var processingFee: Double {
        (Double(amountRequested) ?? 0) - (Double(amountReceived) ?? 0)
    }

    var isValid: Bool {
        (Double(amountRequested) ?? 0) > 0 && (Double(amountReceived) ?? 0) > 0
    }

    // Block if received > requested in same-unit contexts (same currency or non-FX)
    var isProfitTransaction: Bool {
        let requested = Double(amountRequested) ?? 0
        let received = Double(amountReceived) ?? 0
        guard requested > 0, received > 0 else { return false }
        return (isSameCurrency || !isForeignExchange) && received > requested
    }

    var requestedLabel: String {
        "Amount Requested (\(platform.displayCurrency))"
    }

    var receivedLabel: String {
        if isSameCurrency { return "Amount Received (\(platform.displayCurrency))" }
        return isForeignExchange ? "Amount Received (\(baseCurrency))" : "Amount Received (\(platform.displayCurrency))"
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
            .navigationTitle("Record Withdrawal")
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
        .alert("Permanently Save Withdrawal?", isPresented: $showLockConfirmation) {
            Button("Confirm") { performSave() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This withdrawal will be permanently saved and cannot be edited or deleted after confirmation. Are you sure?")
        }
    }

    var amountsSection: some View {
        Section {
            // Amount Requested (always in platform currency)
            HStack {
                Text(requestedLabel).foregroundColor(.appPrimary)
                Spacer()
                TextField("0.00", text: $amountRequested)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.appPrimary)
                    .frame(width: 120)
                    .onChange(of: amountRequested) { _, _ in recalcRate() }
            }
            .listRowBackground(Color.appSurface)

            // Amount Received (base currency if FX ON, platform currency if FX OFF)
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
                        Text("\(baseCurrency)/\(platform.displayCurrency)")
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
                ForEach(withdrawalMethods, id: \.self) { Text($0) }
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
                Text("Save Withdrawal")
                    .font(.headline)
                    .foregroundColor(isValid ? .black : .appSecondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 4)
            }
            .disabled(!isValid)
            .listRowBackground(isValid ? Color.appGold : Color.appSurface2)
        }
    }

    func recalcRate() {
        let req = Double(amountRequested) ?? 0
        let rec = Double(amountReceived) ?? 0
        if req > 0, rec > 0 { effectiveRateStr = String(format: "%.4f", rec / req) }
    }

    func performSave() {
        let withdrawal = Withdrawal(context: viewContext)
        withdrawal.id = UUID()
        withdrawal.date = date
        withdrawal.amountRequested = Double(amountRequested) ?? 0
        withdrawal.amountReceived = Double(amountReceived) ?? 0
        withdrawal.method = method
        withdrawal.platform = platform

        if isSameCurrency {
            withdrawal.isForeignExchange = false
            withdrawal.effectiveExchangeRate = 0
            withdrawal.processingFee = processingFee
        } else if isForeignExchange {
            withdrawal.isForeignExchange = true
            withdrawal.effectiveExchangeRate = Double(effectiveRateStr) ?? computedEffectiveRate
            withdrawal.processingFee = 0
        } else {
            withdrawal.isForeignExchange = false
            withdrawal.effectiveExchangeRate = 0
            withdrawal.processingFee = processingFee
        }

        // Platform balance decreases by amount requested (always in platform currency)
        platform.currentBalance -= withdrawal.amountRequested

        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Save withdrawal error: \(error)")
        }
    }
}
