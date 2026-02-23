import SwiftUI
import CoreData

struct AddAdjustmentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("baseCurrency") private var baseCurrency = "CAD"

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Platform.name, ascending: true)],
        animation: .default
    ) private var platforms: FetchedResults<Platform>

    @State private var name = ""
    @State private var amount = ""
    @State private var date = Date()
    @State private var currency = "CAD"
    @State private var exchangeRate = "1.0000"
    @State private var isOnline = false
    @State private var selectedPlatform: Platform? = nil
    @State private var location = ""
    @State private var notes = ""

    var amountDouble: Double { Double(amount) ?? 0 }
    var exchangeRateDouble: Double { Double(exchangeRate) ?? 1.0 }
    var amountBase: Double { amountDouble * exchangeRateDouble }
    var isSameCurrency: Bool { currency == baseCurrency }

    var isValid: Bool {
        !name.isEmpty && amountDouble != 0
    }

    let commonNames = ["Discrepancy Fix", "Coaching Fee", "Transfer Error", "Other"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                Form {
                    nameSection
                    amountSection
                    typeSection
                    notesSection
                    saveSection
                }
                .scrollContentBackground(.hidden)
                .background(Color.appBackground)
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
                currency = baseCurrency
            }
        }
    }

    var nameSection: some View {
        Section {
            TextField("Name", text: $name)
                .foregroundColor(.appPrimary)
                .listRowBackground(Color.appSurface)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(commonNames, id: \.self) { suggestion in
                        Button {
                            name = suggestion
                        } label: {
                            Text(suggestion)
                                .font(.caption)
                                .foregroundColor(name == suggestion ? .black : .appSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(name == suggestion ? Color.appGold : Color.appSurface2)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(Color.appSurface)
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        } header: {
            Text("Name").foregroundColor(.appGold).textCase(nil)
        }
    }

    var amountSection: some View {
        Section {
            HStack {
                Text("Amount")
                    .foregroundColor(.appPrimary)
                Text("(negative = cost)")
                    .font(.caption)
                    .foregroundColor(.appSecondary)
                Spacer()
                TextField("0.00", text: $amount)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.appGold)
                    .frame(width: 100)
            }
            .listRowBackground(Color.appSurface)

            DatePicker("Date", selection: $date, displayedComponents: .date)
                .foregroundColor(.appPrimary)
                .tint(.appGold)
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

            if amountDouble != 0 {
                HStack {
                    Text("In \(baseCurrency)")
                        .foregroundColor(.appSecondary)
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

    var typeSection: some View {
        Section {
            Toggle(isOn: $isOnline) {
                Text("Online Platform")
                    .foregroundColor(.appPrimary)
            }
            .tint(.appGold)
            .listRowBackground(Color.appSurface)

            if isOnline {
                if platforms.isEmpty {
                    Text("No platforms added yet.")
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                        .listRowBackground(Color.appSurface)
                } else {
                    Picker("Platform", selection: $selectedPlatform) {
                        Text("None").tag(Platform?.none)
                        ForEach(Array(platforms)) { platform in
                            Text(platform.displayName).tag(Optional(platform))
                        }
                    }
                    .foregroundColor(.appPrimary)
                    .tint(.appGold)
                    .listRowBackground(Color.appSurface)
                }
            } else {
                HStack {
                    Text("Location (optional)")
                        .foregroundColor(.appPrimary)
                    Spacer()
                    TextField("Casino / location", text: $location)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.appGold)
                }
                .listRowBackground(Color.appSurface)
            }
        } header: {
            Text("Type").foregroundColor(.appGold).textCase(nil)
        }
    }

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

    var saveSection: some View {
        Section {
            Button {
                saveAdjustment()
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

    func saveAdjustment() {
        let adjustment = Adjustment(context: viewContext)
        adjustment.id = UUID()
        adjustment.name = name
        adjustment.amount = amountDouble
        adjustment.date = date
        adjustment.currency = currency
        adjustment.exchangeRateToBase = exchangeRateDouble
        adjustment.amountBase = amountBase
        adjustment.isOnline = isOnline
        adjustment.platform = isOnline ? selectedPlatform : nil
        adjustment.location = isOnline ? nil : (location.isEmpty ? nil : location)
        adjustment.notes = notes.isEmpty ? nil : notes

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
        .preferredColorScheme(.dark)
}
