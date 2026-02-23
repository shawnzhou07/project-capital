// ContentView.swift is replaced by RootView in App.swift
// This file is kept for SwiftUI preview compatibility

import SwiftUI
import CoreData

struct ContentView: View {
    var body: some View {
        MainTabView()
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .preferredColorScheme(.dark)
}
