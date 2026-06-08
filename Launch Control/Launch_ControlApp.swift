//
//  Launch_ControlApp.swift
//  Launch Control
//
//  Created by Arturo Ayala on 3/17/26.
//

import SwiftUI
import SwiftData

@main
struct Launch_ControlApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Event.self])
        let appGroupID = "group.AA.Launch-Control"
        let config: ModelConfiguration
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            config = ModelConfiguration(schema: schema, url: groupURL.appendingPathComponent("LaunchControl.store"))
        } else {
            config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        }
        do {
            return try ModelContainer(for: schema, configurations: [config])
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
