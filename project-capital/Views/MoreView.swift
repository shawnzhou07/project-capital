import SwiftUI
import CoreData

struct MoreView: View {
    @EnvironmentObject var coordinator: ActiveSessionCoordinator
    @Environment(\.managedObjectContext) private var viewContext

    @State private var showDirectAdjustment = false
    @State private var directAdjustmentPlatform: Platform? = nil

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            List {
                NavigationLink {
                    AdjustmentsListView()
                } label: {
                    Label("Adjustments", systemImage: "plusminus.circle.fill")
                        .foregroundColor(.appPrimary)
                }
                .listRowBackground(Color.appSurface)

                NavigationLink {
                    SettingsView()
                } label: {
                    Label("Settings", systemImage: "gearshape.fill")
                        .foregroundColor(.appPrimary)
                }
                .listRowBackground(Color.appSurface)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
        }
        .navigationTitle("More")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { handleAdjustmentTrigger() }
        .onChange(of: coordinator.adjustmentPlatformID) { _, _ in handleAdjustmentTrigger() }
        .sheet(isPresented: $showDirectAdjustment) {
            if let p = directAdjustmentPlatform {
                AddAdjustmentView(initialPlatform: p)
                    .environment(\.managedObjectContext, viewContext)
                    .environmentObject(coordinator)
            }
        }
    }

    func handleAdjustmentTrigger() {
        guard let id = coordinator.adjustmentPlatformID else { return }
        if let platform = try? viewContext.existingObject(with: id) as? Platform {
            directAdjustmentPlatform = platform
            showDirectAdjustment = true
            coordinator.adjustmentPlatformID = nil
        }
    }
}

#Preview {
    NavigationStack {
        MoreView()
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    .environmentObject(ActiveSessionCoordinator())
    .preferredColorScheme(.dark)
}
