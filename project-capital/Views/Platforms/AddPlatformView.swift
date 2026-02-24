import SwiftUI
import CoreData

struct AddPlatformView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Platform.name, ascending: true)],
        animation: .default
    ) private var existingPlatforms: FetchedResults<Platform>

    @State private var selectedTab = 0  // 0 = predefined, 1 = custom
    @State private var selectedTemplate: PlatformTemplate? = nil
    @State private var customName = ""
    @State private var customCurrency = "USD"

    var availablePredefined: [PlatformTemplate] {
        let existingNames = Set(existingPlatforms.compactMap { $0.name })
        return PlatformTemplate.predefined.filter { !existingNames.contains($0.name) }
    }

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
                if availablePredefined.isEmpty {
                    Text("All predefined platforms have already been added.")
                        .font(.subheadline)
                        .foregroundColor(.appSecondary)
                        .multilineTextAlignment(.center)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.appSurface)
                        .cornerRadius(8)
                }
                ForEach(availablePredefined) { template in
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
                    ForEach(supportedCurrencies, id: \.self) { Text($0).tag($0) }
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
        platform.currentBalance = 0
        if selectedTab == 0, let template = selectedTemplate {
            platform.name = template.name
            platform.currency = template.currency
        } else {
            platform.name = customName
            platform.currency = customCurrency
        }

        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Save error: \(error)")
        }
    }
}
