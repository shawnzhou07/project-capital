import SwiftUI
import CoreData
import UIKit

struct AdjustmentDetailView: View {
    @ObservedObject var adjustment: Adjustment
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("baseCurrency") private var baseCurrency = "CAD"

    @State private var name = ""
    @State private var notes = ""
    @State private var loaded = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            Form {
                lockedSection
                editableSection
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
        }
        .navigationTitle("Adjustment")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadFromAdjustment() }
        .onChange(of: name) { _, _ in autoSave() }
        .onChange(of: notes) { _, _ in autoSave() }
    }

    // MARK: - Locked Fields Section

    var lockedSection: some View {
        Section {
            lockedRow(label: "Amount", value: AppFormatter.currencySigned(adjustment.amount, code: adjustment.currency ?? baseCurrency))
            if let currency = adjustment.currency, currency != baseCurrency {
                lockedRow(label: "In \(baseCurrency)", value: AppFormatter.currencySigned(adjustment.amountBase, code: baseCurrency))
            }
            lockedRow(label: "Date", value: AppFormatter.shortDate(adjustment.date ?? Date()))
            if let platform = adjustment.platform {
                lockedRow(label: "Platform", value: platform.displayName)
            }
        } header: {
            Text("Details").foregroundColor(.appGold).textCase(nil)
        } footer: {
            Text("Amount, date, and platform are permanently locked.")
                .foregroundColor(.appSecondary)
        }
    }

    // MARK: - Editable Fields Section

    @ViewBuilder
    var editableSection: some View {
        Section {
            HStack {
                Text("Name").foregroundColor(.appPrimary)
                Spacer()
                TextField("Adjustment name", text: $name)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.appGold)
            }
            .listRowBackground(Color.appSurface)
        } header: {
            Text("Name").foregroundColor(.appGold).textCase(nil)
        }
        Section {
            TextEditor(text: $notes)
                .frame(minHeight: 80)
                .foregroundColor(.appPrimary)
                .scrollContentBackground(.hidden)
                .background(Color.appSurface)
                .listRowBackground(Color.appSurface)
        } header: {
            Text("Notes").foregroundColor(.appGold).textCase(nil)
        }
    }

    // MARK: - Locked Row

    @ViewBuilder
    func lockedRow(label: String, value: String) -> some View {
        Button {
            triggerLockHaptic()
        } label: {
            HStack {
                Text(label).foregroundColor(.appPrimary)
                Spacer()
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundColor(.appGold)
                Text(value).foregroundColor(.appSecondary)
            }
        }
        .listRowBackground(Color.appSurface)
    }

    // MARK: - Helpers

    func triggerLockHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.impactOccurred()
    }

    func loadFromAdjustment() {
        guard !loaded else { return }
        loaded = true
        name = adjustment.name ?? ""
        notes = adjustment.notes ?? ""
    }

    func autoSave() {
        guard loaded else { return }
        adjustment.name = name.isEmpty ? nil : name
        adjustment.notes = notes.isEmpty ? nil : notes
        try? viewContext.save()
    }
}

#Preview {
    NavigationStack {
        AdjustmentDetailView(adjustment: {
            let ctx = PersistenceController.preview.container.viewContext
            let a = Adjustment(context: ctx)
            a.id = UUID()
            a.name = "Deposit correction"
            a.amount = 50
            a.amountBase = 68
            a.date = Date()
            a.currency = "USD"
            a.exchangeRateToBase = 1.36
            a.isOnline = true
            a.notes = "Balance adjustment"
            return a
        }())
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    .preferredColorScheme(.dark)
}
