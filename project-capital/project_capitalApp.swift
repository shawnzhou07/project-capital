//
//  project_capitalApp.swift
//  project-capital
//
//  Created by Shawn Zhou on 2026-02-23.
//

import SwiftUI
import CoreData

@main
struct project_capitalApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
