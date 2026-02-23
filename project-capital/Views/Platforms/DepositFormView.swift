import SwiftUI
import CoreData

struct DepositFormView: View {
    let platform: Platform
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("baseCurrency") private var baseCurrency = "CAD"

    @State private var amountSent = ""
    @State private var amountReceived = ""
    @State private var date = Date()
    @State private var isForeignExchange = true
    @State private var method = "E-Transfer"
    @State private var notes = ""

    var effectiveRate: Double {
        let sent = Double(amountSent) ?? 0
        let received = Double(amountReceived) ?? 0
        guard sent > 0, received > 0 else { return 0 }
        return sent / received
    }

    var processingFee: Double {
        let sent = Double(amountSent) ?? 0
        let received = Double(amountReceived) ?? 0
        return sent - received
    }

    var isSameCurrency: Bool { platform.displayCurrency == baseCurrency }
    var isValid: Bool {
        (Double(amountSent) ?? 0) > 0 && (Double(amountReceived) ?? 0) > 0
    }

    var body: some View {
        NavigationView {
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
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.appSecondary)
                }
            }
        }
    }

    var amountsSection: some View {
        Section {
            HStack {
                Text("Amount Sent")
                    .foregroundColor(.appPrimary)
                Spacer()
                Text(baseCurrency).font(.caption).foregroundColor(.appSecondary)
                TextField("0.00", text: $amountSent)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.appPrimary)
                    .frame(width: 100)
            }
            .listRowBackground(Color.appSurface)

            HStack {
                Text("Amount Received")
                    .foregroundColor(.appPrimary)
                Spacer()
                Text(platform.displayCurrency).font(.caption).foregroundColor(.appSecondary)
                TextField("0.00", text: $amountReceived)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.appPrimary)
                    .frame(width: 100)
            }
            .listRowBackground(Color.appSurface)

            if !isSameCurrency {
                Toggle(isOn: $isForeignExchange) {
                    Text("Foreign Exchange").foregroundColor(.appPrimary)
                }
                .tint(.appGold)
                .listRowBackground(Color.appSurface)

                if isForeignExchange && effectiveRate > 0 {
                    HStack {
                        Text("Effective Rate")
                            .foregroundColor(.appSecondary)
                        Spacer()
                        Text(AppFormatter.exchangeRate(effectiveRate))
                            .foregroundColor(.appGold)
                        Text("\(baseCurrency)/\(platform.displayCurrency)")
                            .font(.caption)
                            .foregroundColor(.appSecondary)
                    }
                    .listRowBackground(Color.appSurface)
                } else if !isForeignExchange && processingFee != 0 {
                    HStack {
                        Text("Processing Fee")
                            .foregroundColor(.appSecondary)
                        Spacer()
                        Text(AppFormatter.currency(processingFee, code: baseCurrency))
                            .foregroundColor(.appNeutral)
                    }
                    .listRowBackground(Color.appSurface)
                }
            }
        } header: {
            Text("Amounts").foregroundColor(.appGold).textCase(nil)
        }
    }

    var detailsSection: some View {
        Section {
            DatePicker("Date", selection: $date, displayedComponents: .date)
                .foregroundColor(.appPrimary)
                .tint(.appGold)
                .listRowBackground(Color.appSurface)

            Picker("Method", selection: $method) {
                ForEach(depositMethods, id: \.self) { Text($0) }
            }
            .foregroundColor(.appPrimary)
            .tint(.appGold)
            .listRowBackground(Color.appSurface)
        } header: {
            Text("Details").foregroundColor(.appGold).textCase(nil)
        }
    }

    var saveSection: some View {
        Section {
            Button {
                saveDeposit()
            } label: {
                Text("Save Deposit")
                    .font(.headline)
                    .foregroundColor(isValid ? .black : .appSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .disabled(!isValid)
            .listRowBackground(isValid ? Color.appGold : Color.appSurface2)
        }
    }

    func saveDeposit() {
        let deposit = Deposit(context: viewContext)
        deposit.id = UUID()
        deposit.date = date
        deposit.amountSent = Double(amountSent) ?? 0
        deposit.amountReceived = Double(amountReceived) ?? 0
        deposit.isForeignExchange = isForeignExchange
        deposit.effectiveExchangeRate = isForeignExchange ? effectiveRate : 0
        deposit.processingFee = isForeignExchange ? 0 : processingFee
        deposit.method = method
        deposit.platform = platform

        // Update platform balance
        platform.currentBalance += deposit.amountReceived

        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Save deposit error: \(error)")
        }
    }
}
