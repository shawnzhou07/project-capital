import SwiftUI
import CoreData

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("baseCurrency") private var baseCurrency = "CAD"
    @AppStorage("handsPerHourOnline") private var handsPerHourOnline = 85
    @AppStorage("handsPerHourLive") private var handsPerHourLive = 25
    @AppStorage("exchangeRateInputMode") private var exchangeRateInputMode = "direct"
    @AppStorage("defaultRateUSDToBase") private var defaultRateUSDToBase = 1.36
    @AppStorage("defaultRateEURToBase") private var defaultRateEURToBase = 1.47
    @AppStorage("defaultRateUSDToEUR") private var defaultRateUSDToEUR = 0.92
    @State private var showResetConfirmation = false

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
        .navigationBarTitleDisplayMode(.large)
        .alert("Reset All Data?", isPresented: $showResetConfirmation) {
            Button("Reset Everything", role: .destructive) { performReset() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all sessions, platforms, deposits, withdrawals, and adjustments. This cannot be undone.")
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
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                }
            }
            .listRowBackground(Color.appSurface)

            Button {
                importData()
            } label: {
                HStack {
                    Text("Import Data")
                        .foregroundColor(.appPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
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

    func exportData() {
        // TODO: Implement data export
    }

    func importData() {
        // TODO: Implement data import
    }

    func performReset() {
        let entityNames = ["OnlineCash", "LiveCash", "Platform", "Deposit", "Withdrawal", "Adjustment"]
        for name in entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: name)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            let _ = try? viewContext.execute(deleteRequest)
        }
        try? viewContext.save()
    }
}

#Preview {
    SettingsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .preferredColorScheme(.dark)
}
