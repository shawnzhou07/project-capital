import SwiftUI
import CoreData

struct AddAdjustmentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var coordinator: ActiveSessionCoordinator
    @AppStorage("baseCurrency") private var baseCurrency = "CAD"

    /// Pre-selected and locked platform (from platform detail or discrepancy redirect).
    var initialPlatform: Platform? = nil

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Platform.name, ascending: true)],
        animation: .default
    ) private var platforms: FetchedResults<Platform>

    @State private var name = ""
    @State private var amount = ""
    @State private var date = Date()
    @State private var selectedPlatform: Platform? = nil
    @State private var notes = ""
    @State private var showSaveConfirmation = false

    var isInitialPlatformLocked: Bool { initialPlatform != nil }
    var amountDouble: Double { Double(amount) ?? 0 }
    var platformCurrency: String { selectedPlatform?.displayCurrency ?? baseCurrency }
    var conversionRate: Double { selectedPlatform?.latestFXConversionRate ?? 1.0 }
    var amountBase: Double { amountDouble * conversionRate }
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && amountDouble != 0 && selectedPlatform != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                // Show empty state when no platforms exist and none was pre-selected.
                if platforms.isEmpty && initialPlatform == nil {
                    noPlatformsState
                } else {
                    Form {
                        nameSection
                        amountSection
                        if isInitialPlatformLocked {
                            lockedPlatformSection
                        } else {
                            platformSection
                        }
                        notesSection
                        saveSection
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.appBackground)
                }
            }
            .navigationTitle("New Adjustment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.appSecondary)
                }
            }
            .onAppear {
                if let ip = initialPlatform {
                    selectedPlatform = ip
                }
            }
            .alert("Save Adjustment?", isPresented: $showSaveConfirmation) {
                Button("Save") { saveAdjustment() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This adjustment will be permanently saved and cannot be edited or deleted after confirmation.")
            }
        }
    }

    // MARK: - No Platforms State

    var noPlatformsState: some View {
        VStack(spacing: 16) {
            Image(systemName: "building.columns")
                .font(.system(size: 48))
                .foregroundColor(.appSecondary)
            Text("No Platforms Available")
                .font(.headline)
                .foregroundColor(.appPrimary)
            Text("Adjustments must be linked to an online platform. Please add a platform first.")
                .font(.subheadline)
                .foregroundColor(.appSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                dismiss()
                coordinator.shouldOpenAddPlatform = true
                coordinator.selectedTab = 2
            } label: {
                Text("Go to Platforms")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.appGold)
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Name

    var nameSection: some View {
        Section {
            TextField("e.g. Deposit correction, Transfer error", text: $name)
                .foregroundColor(.appPrimary)
                .listRowBackground(Color.appSurface)
        } header: {
            Text("Name").foregroundColor(.appGold).textCase(nil)
        }
    }

    // MARK: - Amount

    var amountSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Amount").foregroundColor(.appPrimary)
                    Text("Positive adds to balance, negative subtracts")
                        .font(.caption2)
                        .foregroundColor(.appSecondary)
                }
                Spacer()
                CurrencyInputField(text: $amount, width: 100, textColor: .appGold, allowsNegative: true)
            }
            .listRowBackground(Color.appSurface)

            // Currency is locked to the selected platform's currency.
            HStack {
                Text("Currency").foregroundColor(.appSecondary)
                Spacer()
                Text(platformCurrency).foregroundColor(.appSecondary)
                Image(systemName: "lock.fill")
                    .font(.caption2)
                    .foregroundColor(.appSecondary)
            }
            .listRowBackground(Color.appSurface)

            DatePicker("Date", selection: $date, displayedComponents: .date)
                .foregroundColor(.appPrimary)
                .tint(.appGold)
                .listRowBackground(Color.appSurface)

            // Show base currency equivalent only for foreign-currency platforms.
            if amountDouble != 0 && platformCurrency != baseCurrency {
                HStack {
                    Text("In \(baseCurrency)").foregroundColor(.appSecondary)
                    Spacer()
                    Text(AppFormatter.currencySigned(amountBase, code: baseCurrency))
                        .foregroundColor(amountBase.profitColor)
                }
                .listRowBackground(Color.appSurface)
            }
        } header: {
            Text("Amount").foregroundColor(.appGold).textCase(nil)
        }
    }

    // MARK: - Platform Picker (when not pre-locked)

    var platformSection: some View {
        Section {
            Picker("Platform", selection: $selectedPlatform) {
                Text("Select Platform").tag(Platform?.none)
                ForEach(Array(platforms)) { platform in
                    Text(platform.displayName).tag(Optional(platform))
                }
            }
            .foregroundColor(.appPrimary)
            .tint(.appGold)
            .listRowBackground(Color.appSurface)
        } header: {
            Text("Platform").foregroundColor(.appGold).textCase(nil)
        }
    }

    // MARK: - Locked Platform Row

    var lockedPlatformSection: some View {
        Section {
            HStack {
                Text("Platform").foregroundColor(.appPrimary)
                Spacer()
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundColor(.appGold)
                Text(selectedPlatform?.displayName ?? "—")
                    .foregroundColor(.appPrimary)
            }
            .listRowBackground(Color.appSurface)
        } header: {
            Text("Platform").foregroundColor(.appGold).textCase(nil)
        }
    }

    // MARK: - Notes

    var notesSection: some View {
        Section {
            TextEditor(text: $notes)
                .frame(minHeight: 60)
                .foregroundColor(.appPrimary)
                .scrollContentBackground(.hidden)
                .background(Color.appSurface)
                .listRowBackground(Color.appSurface)
        } header: {
            Text("Notes (optional)").foregroundColor(.appGold).textCase(nil)
        }
    }

    // MARK: - Save Button

    var saveSection: some View {
        Section {
            Button {
                showSaveConfirmation = true
            } label: {
                Text("Save Adjustment")
                    .font(.headline)
                    .foregroundColor(isValid ? .black : .appSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .disabled(!isValid)
            .listRowBackground(isValid ? Color.appGold : Color.appSurface2)
        }
    }

    // MARK: - Save Logic

    func saveAdjustment() {
        guard let platform = selectedPlatform else { return }
        let adjustment = Adjustment(context: viewContext)
        adjustment.id = UUID()
        adjustment.name = name.trimmingCharacters(in: .whitespaces)
        adjustment.amount = amountDouble
        adjustment.date = date
        // Currency is always locked to the linked platform's currency.
        adjustment.currency = platform.displayCurrency
        adjustment.exchangeRateToBase = conversionRate
        adjustment.amountBase = amountBase
        adjustment.isOnline = true
        adjustment.platform = platform
        adjustment.location = nil
        adjustment.notes = notes.isEmpty ? nil : notes

        // Apply directly to the platform's current balance.
        platform.currentBalance += amountDouble

        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Save adjustment error: \(error)")
        }
    }
}

#Preview {
    AddAdjustmentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ActiveSessionCoordinator())
        .preferredColorScheme(.dark)
}
