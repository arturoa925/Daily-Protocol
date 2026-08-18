

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
        // Gives UI tests a known-clean starting state: without this, the SwiftData
        // store and @AppStorage settings persist across separate test runs on the
        // simulator, and leftover data from one test shifts UI another test expects
        // to find at a fixed position.
        let isUITestReset = ProcessInfo.processInfo.arguments.contains("-uiTestReset")
        if isUITestReset, let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }

        let container = Self.makeModelContainer(resetStore: isUITestReset)
        sharedModelContainer = container
        notificationDelegate = EventNotificationDelegate(modelContainer: container)
        UNUserNotificationCenter.current().delegate = notificationDelegate
        NotificationScheduler.registerCategories()
    }

    private static func makeModelContainer(resetStore: Bool = false) -> ModelContainer {
        let schema = Schema([Event.self])
        let appGroupID = "group.AA.Launch-Control"
        let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
        let config: ModelConfiguration
        if let groupURL {
            config = ModelConfiguration(schema: schema, url: groupURL.appendingPathComponent("LaunchControl.store"))
        } else {
            config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        }

        if resetStore {
            // Whether the App Group container resolves has been observed to vary by
            // launch context (e.g. a UI test runner process vs. a plain simulator
            // launch), which would silently point separate launches at two different
            // store files. Clearing both possible locations makes the reset correct
            // regardless of which one `config` above actually resolved to.
            removeStoreFiles(for: config)
            removeStoreFiles(for: ModelConfiguration(schema: schema, isStoredInMemoryOnly: false))
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
