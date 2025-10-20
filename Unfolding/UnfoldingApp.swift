//
//  UnfoldingApp.swift
//  Unfolding
//
//  Created by Rongwei Ji on 10/2/25.
//

import SwiftUI
import SwiftData

@main
struct UnfoldingApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            PhotoRecord.self,
        ])

        // Configure ModelConfiguration with CloudKit sync
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.com.aequatione.unfolding")
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

