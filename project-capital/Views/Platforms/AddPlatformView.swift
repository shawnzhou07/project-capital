import SwiftUI
import CoreData

struct AddPlatformView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab = 0  // 0 = predefined, 1 = custom
    @State private var selectedTemplate: PlatformTemplate? = nil
    @State private var customName = ""
    @State private var customCurrency = "USD"
    @State private var openingBalance = ""

    var canSave: Bool {
        if selectedTab == 0 {
            return selectedTemplate != nil
        }
        return !customName.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    Picker("Type", selection: $selectedTab) {
                        Text("Predefined").tag(0)
                        Text("Custom").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    if selectedTab == 0 {
                        predefinedList
                    } else {
                        customForm
                    }

                    Spacer()

                    balanceInput
                    saveButton
                }
            }
            .navigationTitle("Add Platform")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.appSecondary)
                }
            }
        }
    }

    var predefinedList: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(PlatformTemplate.predefined) { template in
                    Button {
                        selectedTemplate = template
                    } label: {
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
                            Image(systemName: selectedTemplate?.id == template.id ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedTemplate?.id == template.id ? .appGold : .appSecondary)
                        }
                        .padding()
                        .background(selectedTemplate?.id == template.id ? Color.appSurface2 : Color.appSurface)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selectedTemplate?.id == template.id ? Color.appGold : Color.appBorder, lineWidth: 1)
                        )
                    }
                }
            }
            .padding()
        }
    }

    var customForm: some View {
        Form {
            Section {
                HStack {
                    Text("Name").foregroundColor(.appPrimary)
                    Spacer()
                    TextField("Platform Name", text: $customName)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.appGold)
                }
                .listRowBackground(Color.appSurface)

                Picker("Currency", selection: $customCurrency) {
                    ForEach(["CAD", "USD", "EUR", "GBP"], id: \.self) { Text($0).tag($0) }
                }
                .foregroundColor(.appPrimary)
                .tint(.appGold)
                .listRowBackground(Color.appSurface)
            } header: {
                Text("Details").foregroundColor(.appGold).textCase(nil)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
    }

    var balanceInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Opening Balance")
                .font(.subheadline)
                .foregroundColor(.appSecondary)
            HStack {
                Text("$")
                    .foregroundColor(.appSecondary)
                TextField("0.00", text: $openingBalance)
                    .keyboardType(.decimalPad)
                    .foregroundColor(.appPrimary)
                Spacer()
                Text(selectedTab == 0 ? (selectedTemplate?.currency ?? "USD") : customCurrency)
                    .font(.caption)
                    .foregroundColor(.appSecondary)
            }
            .padding()
            .background(Color.appSurface)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, lineWidth: 1))
        }
        .padding()
    }

    var saveButton: some View {
        Button {
            savePlatform()
        } label: {
            Text("Add Platform")
                .font(.headline)
                .foregroundColor(canSave ? .black : .appSecondary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(canSave ? Color.appGold : Color.appSurface2)
                .cornerRadius(8)
        }
        .disabled(!canSave)
        .padding()
    }

    func savePlatform() {
        let platform = Platform(context: viewContext)
        platform.id = UUID()
        platform.createdAt = Date()
        if selectedTab == 0, let template = selectedTemplate {
            platform.name = template.name
            platform.currency = template.currency
        } else {
            platform.name = customName
            platform.currency = customCurrency
        }
        platform.currentBalance = Double(openingBalance) ?? 0

        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Save error: \(error)")
        }
    }
}
