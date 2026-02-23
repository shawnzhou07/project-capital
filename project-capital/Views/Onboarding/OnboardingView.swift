import SwiftUI
import CoreData

struct OnboardingView: View {
    @State private var step = 0
    @State private var selectedCurrency = "CAD"
    @State private var selectedExchangeMode = "direct"
    @State private var selectedPlatforms: Set<String> = []
    @State private var platformBalances: [String: String] = [:]
    @State private var customPlatformName = ""
    @State private var customPlatformCurrency = "USD"
    @State private var showCustomPlatform = false

    @AppStorage("baseCurrency") private var baseCurrency = "CAD"
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            switch step {
            case 0: welcomeStep
            case 1: currencyStep
            case 2: exchangeRateModeStep
            case 3: platformsStep
            case 4: balancesStep
            default: welcomeStep
            }
        }
        .animation(.easeInOut(duration: 0.3), value: step)
    }

    // MARK: - Step 0: Welcome

    var welcomeStep: some View {
        VStack(spacing: 40) {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "suit.spade.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.appGold)
                Text("Project Capital")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.appPrimary)
                Text("Track your real poker profits.")
                    .font(.title3)
                    .foregroundColor(.appSecondary)
            }
            Spacer()
            Button {
                withAnimation { step = 1 }
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.appGold)
                    .cornerRadius(8)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    // MARK: - Step 1: Base Currency

    var currencyStep: some View {
        VStack(spacing: 0) {
            OnboardingHeader(title: "Base Currency", subtitle: "All profits will be reported in this currency. This cannot be changed later.", step: "1 of 4")
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(["CAD", "USD", "EUR"], id: \.self) { currency in
                        CurrencySelectionCard(
                            currency: currency,
                            isSelected: selectedCurrency == currency
                        ) {
                            selectedCurrency = currency
                        }
                    }
                    Text("This setting is permanent. Choose carefully.")
                        .font(.caption)
                        .foregroundColor(.appLoss)
                        .padding(.top, 8)
                }
                .padding()
            }
            OnboardingNextButton(title: "Continue") {
                baseCurrency = selectedCurrency
                withAnimation { step = 2 }
            }
        }
    }

    // MARK: - Step 2: Exchange Rate Input Mode

    var exchangeRateModeStep: some View {
        VStack(spacing: 0) {
            OnboardingHeader(
                title: "Exchange Rate Input",
                subtitle: "How do you prefer to enter exchange rates for foreign currency sessions?",
                step: "2 of 4"
            )
            ScrollView {
                VStack(spacing: 12) {
                    ExchangeModeCard(
                        title: "Enter Rate Directly",
                        description: "You type the exchange rate (e.g. 1.36 CAD per USD). We calculate the base currency equivalent for you.",
                        example: "Rate: 1.36  →  $100 USD = $136 CAD",
                        isSelected: selectedExchangeMode == "direct"
                    ) {
                        selectedExchangeMode = "direct"
                    }
                    ExchangeModeCard(
                        title: "Enter Amounts",
                        description: "You type how much you paid or received in both currencies. We calculate the effective exchange rate automatically.",
                        example: "Paid $136 CAD, received $100 USD  →  Rate: 1.36",
                        isSelected: selectedExchangeMode == "amounts"
                    ) {
                        selectedExchangeMode = "amounts"
                    }
                    Text("This can be changed later in Settings → Exchange Rate Input.")
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .padding()
            }
            OnboardingNextButton(title: "Continue") {
                UserDefaults.standard.set(selectedExchangeMode, forKey: "exchangeRateInputMode")
                withAnimation { step = 3 }
            }
        }
    }

    // MARK: - Step 3: Select Platforms

    var platformsStep: some View {
        VStack(spacing: 0) {
            OnboardingHeader(title: "Your Platforms", subtitle: "Select the online poker platforms you play on. You can add more later.", step: "3 of 4")
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(PlatformTemplate.predefined) { template in
                        PlatformSelectionRow(
                            template: template,
                            baseCurrency: selectedCurrency,
                            isSelected: selectedPlatforms.contains(template.name)
                        ) {
                            if selectedPlatforms.contains(template.name) {
                                selectedPlatforms.remove(template.name)
                            } else {
                                selectedPlatforms.insert(template.name)
                            }
                        }
                    }
                    Button {
                        showCustomPlatform = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.appGold)
                            Text("Add Custom Platform")
                                .foregroundColor(.appGold)
                            Spacer()
                        }
                        .padding()
                        .background(Color.appSurface)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.appBorder, lineWidth: 1)
                        )
                    }
                }
                .padding()
            }
            OnboardingNextButton(title: "Continue") {
                withAnimation { step = 4 }
            }
        }
        .sheet(isPresented: $showCustomPlatform) {
            CustomPlatformSheet(name: $customPlatformName, currency: $customPlatformCurrency) { name, currency in
                selectedPlatforms.insert("\(name)|\(currency)")
                showCustomPlatform = false
            }
        }
    }

    // MARK: - Step 4: Opening Balances

    var balancesStep: some View {
        VStack(spacing: 0) {
            OnboardingHeader(title: "Opening Balances", subtitle: "Set current balances for your selected platforms.", step: "4 of 4")
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(selectedPlatforms).sorted(), id: \.self) { key in
                        let parts = key.split(separator: "|")
                        let name = parts.count > 1 ? String(parts[0]) : key
                        let curr = parts.count > 1 ? String(parts[1]) : currency(for: key)
                        BalanceInputRow(
                            platformName: name,
                            currency: curr,
                            balance: Binding(
                                get: { platformBalances[key] ?? "" },
                                set: { platformBalances[key] = $0 }
                            )
                        )
                    }
                    if selectedPlatforms.isEmpty {
                        Text("No platforms selected. You can add them later from the Platforms tab.")
                            .font(.subheadline)
                            .foregroundColor(.appSecondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                }
                .padding()
            }
            OnboardingNextButton(title: "Start Tracking") {
                savePlatformsAndComplete()
            }
        }
    }

    func currency(for key: String) -> String {
        PlatformTemplate.predefined.first { $0.name == key }?.currency ?? "USD"
    }

    func savePlatformsAndComplete() {
        for key in selectedPlatforms {
            let parts = key.split(separator: "|")
            let name: String
            let curr: String
            if parts.count > 1 {
                name = String(parts[0])
                curr = String(parts[1])
            } else {
                name = key
                curr = currency(for: key)
            }
            let platform = Platform(context: viewContext)
            platform.id = UUID()
            platform.name = name
            platform.currency = curr
            platform.createdAt = Date()
            let balanceStr = platformBalances[key] ?? "0"
            platform.currentBalance = Double(balanceStr) ?? 0
        }
        do {
            try viewContext.save()
        } catch {
            print("Failed to save platforms: \(error)")
        }
        hasCompletedOnboarding = true
    }
}

// MARK: - Supporting Views

struct OnboardingHeader: View {
    let title: String
    let subtitle: String
    let step: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(step)
                .font(.caption)
                .foregroundColor(.appGold)
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.appPrimary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.appSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct OnboardingNextButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.appGold)
                .cornerRadius(8)
        }
        .padding()
    }
}

struct CurrencySelectionCard: View {
    let currency: String
    let isSelected: Bool
    let action: () -> Void

    var flag: String {
        switch currency {
        case "CAD": return "🇨🇦"
        case "USD": return "🇺🇸"
        case "EUR": return "🇪🇺"
        default: return "💱"
        }
    }

    var fullName: String {
        switch currency {
        case "CAD": return "Canadian Dollar"
        case "USD": return "US Dollar"
        case "EUR": return "Euro"
        default: return currency
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(flag).font(.title)
                VStack(alignment: .leading, spacing: 2) {
                    Text(currency)
                        .font(.headline)
                        .foregroundColor(.appPrimary)
                    Text(fullName)
                        .font(.subheadline)
                        .foregroundColor(.appSecondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.appGold)
                        .font(.title3)
                }
            }
            .padding()
            .background(isSelected ? Color.appSurface2 : Color.appSurface)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.appGold : Color.appBorder, lineWidth: isSelected ? 1.5 : 1)
            )
        }
    }
}

struct ExchangeModeCard: View {
    let title: String
    let description: String
    let example: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.appPrimary)
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .appGold : .appSecondary)
                        .font(.title3)
                }
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.appSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(example)
                    .font(.caption)
                    .foregroundColor(.appGold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.appSurface2)
                    .cornerRadius(6)
            }
            .padding()
            .background(isSelected ? Color.appSurface2 : Color.appSurface)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.appGold : Color.appBorder, lineWidth: isSelected ? 1.5 : 1)
            )
        }
    }
}

struct PlatformSelectionRow: View {
    let template: PlatformTemplate
    let baseCurrency: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.appPrimary)
                    Text(template.currency)
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                }
                Spacer()
                if template.currency != baseCurrency {
                    Text("FX")
                        .font(.caption2)
                        .foregroundColor(.appGold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.appSurface2)
                        .cornerRadius(4)
                }
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .appGold : .appSecondary)
            }
            .padding()
            .background(isSelected ? Color.appSurface2 : Color.appSurface)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.appGold : Color.appBorder, lineWidth: isSelected ? 1.5 : 1)
            )
        }
    }
}

struct BalanceInputRow: View {
    let platformName: String
    let currency: String
    @Binding var balance: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(platformName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.appPrimary)
                Spacer()
                Text(currency)
                    .font(.caption)
                    .foregroundColor(.appSecondary)
            }
            HStack {
                Text("$")
                    .foregroundColor(.appSecondary)
                TextField("0.00", text: $balance)
                    .keyboardType(.decimalPad)
                    .foregroundColor(.appPrimary)
            }
            .padding(10)
            .background(Color.appSurface2)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.appBorder, lineWidth: 1)
            )
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(8)
    }
}

struct CustomPlatformSheet: View {
    @Binding var name: String
    @Binding var currency: String
    let onSave: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                Form {
                    Section("Platform Details") {
                        TextField("Platform Name", text: $name)
                            .foregroundColor(.appPrimary)
                        Picker("Currency", selection: $currency) {
                            ForEach(["CAD", "USD", "EUR", "GBP"], id: \.self) { Text($0) }
                        }
                    }
                    .listRowBackground(Color.appSurface)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Custom Platform")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.appSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if !name.isEmpty {
                            onSave(name, currency)
                        }
                    }
                    .foregroundColor(.appGold)
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .preferredColorScheme(.dark)
}
