import SwiftUI
import CoreData

struct MainTabView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var sessionCoordinator = ActiveSessionCoordinator()

    init() {
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor.black
        tabBarAppearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color.appGold)
        tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(Color.appGold)]
        tabBarAppearance.stackedLayoutAppearance.normal.iconColor = UIColor(Color.appSecondary)
        tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(Color.appSecondary)]
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = .black
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
    }

    var body: some View {
        TabView {
            SessionsListView()
                .tabItem {
                    Label("Sessions", systemImage: "suit.spade.fill")
                }

            StatsView()
                .tabItem {
                    Label("Stats", systemImage: "chart.bar.fill")
                }

            PlatformsListView()
                .tabItem {
                    Label("Platforms", systemImage: "creditcard.fill")
                }

            AdjustmentsListView()
                .tabItem {
                    Label("Adjustments", systemImage: "plusminus.circle.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(.appGold)
        .environmentObject(sessionCoordinator)
        .safeAreaInset(edge: .bottom) {
            FloatingSessionBar()
                .environmentObject(sessionCoordinator)
        }
        .fullScreenCover(isPresented: $sessionCoordinator.isFormPresented) {
            SessionEntryContainerView()
                .environmentObject(sessionCoordinator)
                .environment(\.managedObjectContext, viewContext)
        }
    }
}

#Preview {
    MainTabView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .preferredColorScheme(.dark)
}
