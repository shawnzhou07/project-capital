import SwiftUI
import CoreData

struct MainTabView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var sessionCoordinator = ActiveSessionCoordinator()

    init() {
        // Navigation bar appearance
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = .black
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance

        // Tab bar appearance
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = .black
        let gold = UIColor(red: 0xC9/255.0, green: 0xB4/255.0, blue: 0x7A/255.0, alpha: 1)
        let gray = UIColor(red: 0x8A/255.0, green: 0x8A/255.0, blue: 0x8A/255.0, alpha: 1)
        tabAppearance.stackedLayoutAppearance.selected.iconColor = gold
        tabAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: gold]
        tabAppearance.stackedLayoutAppearance.normal.iconColor = gray
        tabAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: gray]
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }

    var body: some View {
        TabView {
            NavigationStack {
                SessionsListView()
            }
            .tabItem {
                Label("Sessions", systemImage: "rectangle.stack.fill")
            }

            NavigationStack {
                StatsView()
            }
            .tabItem {
                Label("Stats", systemImage: "chart.bar.fill")
            }

            NavigationStack {
                PlatformsListView()
            }
            .tabItem {
                Label("Platforms", systemImage: "building.columns.fill")
            }

            NavigationStack {
                MoreView()
            }
            .tabItem {
                Label("More", systemImage: "ellipsis")
            }
        }
        .environmentObject(sessionCoordinator)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FloatingSessionBar()
                .environmentObject(sessionCoordinator)
                .environment(\.managedObjectContext, viewContext)
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
