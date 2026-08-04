//
//  Launch_ControlApp.swift
//  Launch Control
//
//  Created by Arturo Ayala on 3/17/26.
//

import SwiftUI
import SwiftData
import UserNotifications
import os

@main
struct Launch_ControlApp: App {
    @AppStorage("appAppearance") private var appearanceRaw: String = AppearanceMode.system.rawValue

    var sharedModelContainer: ModelContainer
    private let notificationDelegate: EventNotificationDelegate

    private static let logger = Logger(subsystem: "AA.Launch-Control", category: "Persistence")

    init() {
        let container = Self.makeModelContainer()
        sharedModelContainer = container
        notificationDelegate = EventNotificationDelegate(modelContainer: container)
        UNUserNotificationCenter.current().delegate = notificationDelegate
        NotificationScheduler.registerCategories()
    }

    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema([Event.self])
        let appGroupID = "group.AA.Launch-Control"
        let config: ModelConfiguration
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            config = ModelConfiguration(schema: schema, url: groupURL.appendingPathComponent("LaunchControl.store"))
        } else {
            config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        }

        if let container = try? ModelContainer(for: schema, configurations: [config]) {
            return container
        }

        logger.error("ModelContainer failed to load; attempting recovery by clearing the on-disk store.")
        removeStoreFiles(for: config)

        if let container = try? ModelContainer(for: schema, configurations: [config]) {
            return container
        }

        logger.fault("ModelContainer recovery failed; falling back to an in-memory store for this session.")
        let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        guard let fallbackContainer = try? ModelContainer(for: schema, configurations: [fallbackConfig]) else {
            fatalError("Could not create even an in-memory ModelContainer.")
        }
        return fallbackContainer
    }

    private static func removeStoreFiles(for config: ModelConfiguration) {
        let fileManager = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            let fileURL = URL(fileURLWithPath: config.url.path + suffix)
            try? fileManager.removeItem(at: fileURL)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme((AppearanceMode(rawValue: appearanceRaw) ?? .system).colorScheme)
        }
        .modelContainer(sharedModelContainer)
    }
}
