import SwiftUI
import CoreData

struct MoreView: View {
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
        .navigationBarTitleDisplayMode(.large)
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
