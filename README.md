# Launch Control

A focused daily planner for iPhone, built with **SwiftUI** and **SwiftData**. Plan what you're getting done today, check things off with a swipe, keep a streak going, and see how your week and month are tracking. You can also do it hands-free through **Siri and Shortcuts**.

> The repository is named `Daily-Protocol`. The app and Xcode project are named **Launch Control**.

---

## Features

### Three screens, one swipe apart
The app is a vertical pager. Swipe up or down to move between screens. The pager only takes over once the current screen's content has scrolled to its edge, so it doesn't fight with scrolling inside a screen.

| Screen | What it does |
| --- | --- |
| **Protocol** | Today's events, the date, and your current 🔥 streak |
| **Calendar** | Pick any date to see, add, and manage its events |
| **Completion** | Weekly bar chart of completed vs. total events, plus a 4-week monthly view and remaining-event counts |

### Events
- Add events with an optional time and reminder
- **Swipe right** to mark an event complete and **swipe left** to undo it
- **Long-press** to add notes (a dot shows on events that have notes)
- **Double-tap** to set a category: Work, Health, Education, Personal, or Social
- Delete with a confirmation alert

### Streaks
`StreakCalculator` counts consecutive days that have at least one completed event. If you haven't completed anything yet today, the count starts from yesterday, so your streak doesn't reset to 0 the moment a new day starts.

### Reminders with a "Mark Complete" action
Reminders are scheduled with `UNCalendarNotificationTrigger` and use a custom notification category. Tapping **Mark Complete** on the notification updates the event in SwiftData without opening the app.

### Siri & Shortcuts (App Intents)
| Intent | Example phrase |
| --- | --- |
| Add Event for Today | "Add event for today in Launch Control" |
| Mark Event Complete | "Mark *[event]* done in Launch Control" |
| Remove Event | "Remove *[event]* in Launch Control" |
| Today's Events | "What do I have today in Launch Control" |

Events are exposed to Siri as an `AppEntity` with an `EntityQuery` / `EntityStringQuery`, so Siri can suggest today's open events and search events by title.

### Settings
- **Appearance:** System, Light, or Dark
- **Action button side:** puts the floating add button on the left or the right for one-handed use

### Accessibility
- Full VoiceOver support: custom labels, hints, values, and named actions (mark complete, edit notes, choose category) so every gesture also works without gestures
- Pages that aren't on screen are removed from the accessibility tree, and the pager responds to VoiceOver's three-finger scroll
- Respects **Reduce Motion**

### Privacy
All data stays on the device. The app has no accounts, no network calls, and no analytics. It ships with a `PrivacyInfo.xcprivacy` privacy manifest that declares no collected data types.

---

## Architecture

```
SwiftUI Views ──► EventEditor (editing state + actions) ──► SwiftData ModelContext
      │                                                         ▲
      └── CompletionCalculator / StreakCalculator (pure logic)  │
                                                                │
App Intents (Siri) ──► IntentContainer (actor) ─────────────────┤
Notification action ──► EventNotificationDelegate ──────────────┘
                     Shared store in the App Group: group.AA.Launch-Control
```

- **One shared SwiftData store.** The app, the App Intents, and the notification delegate all open the same `LaunchControl.store` file in an **App Group** container, so changes made through Siri or a notification show up in the app right away.
- **Actor-isolated container for intents.** App Intents call `EntityQuery` methods outside the main actor. A private `IntentContainer` actor creates the `ModelContainer` once and safely hands it to any async context.
- **Self-healing persistence.** If the store fails to load, the app logs the error, deletes the store files, and tries again. If that also fails, it falls back to an in-memory store instead of crashing.
- **Pure, testable logic.** Streaks, week and month ranges, and completion counts live in stateless enums that take an injectable `Calendar` and reference date.

### Project structure

```
Launch Control/
├── Launch_ControlApp.swift      # App entry, ModelContainer setup + recovery
├── ContentView.swift            # Vertical pager across the three screens
├── SiriIntents.swift            # App Intents, AppEntity, EntityQuery, Shortcuts
├── Models/
│   ├── Event.swift              # SwiftData @Model
│   ├── EventEditor.swift        # Add / edit / complete / delete logic
│   ├── StreakCalculator.swift
│   ├── CompletionCalculator.swift
│   ├── AppearanceMode.swift
│   └── ActionButtonSide.swift
├── Features/
│   ├── Protocol/                # Today
│   ├── Calendar/
│   ├── Completion/              # Weekly + monthly views
│   └── Settings/
└── Components/                  # Sheets, buttons, notifications, colors, pager helpers
Launch ControlTests/             # Unit tests (Swift Testing)
Launch ControlUITests/           # UI tests (XCUITest)
```

---

## Testing

- **Unit tests** use the **Swift Testing** framework (`@Test`). They cover `EventEditor`, event display formatting, appearance and button-side settings, and the pager's scroll-edge logic.
- **UI tests** use **XCUITest** and cover the main flows: adding and deleting events, adding notes, adding events from the calendar, switching between weekly and monthly views, settings that persist across relaunches, and accessibility of off-screen pages.
- When launched with `-uiTestReset`, the app wipes its SwiftData store and `UserDefaults` so every UI test starts from the same empty state.

Run them in Xcode with **⌘U**, or from the command line:

```bash
xcodebuild test \
  -project "Launch Control.xcodeproj" \
  -scheme "Launch Control" \
  -destination "platform=iOS Simulator,name=iPhone 17"
```

---

## Getting Started

### Requirements
- Xcode 26 or later
- iOS 26.2 or later

### Run it
```bash
git clone https://github.com/arturoa925/Daily-Protocol.git
cd Daily-Protocol
open "Launch Control.xcodeproj"
```

1. Select the **Launch Control** target and set your own **Team** under *Signing & Capabilities*.
2. Change the bundle identifier (`AA.Launch-Control`) and the App Group (`group.AA.Launch-Control`) to IDs your team owns, and update the App Group ID in `Launch_ControlApp.swift` and `SiriIntents.swift` to match.
3. Build and run with **⌘R**.

> Siri phrases can take a moment to register after the first install. You can also find the actions in the **Shortcuts** app.

---

## Tech Stack

SwiftUI · SwiftData · App Intents · UserNotifications · Swift Concurrency (actors) · OSLog · Swift Testing · XCUITest

---

## Author

**Arturo Ayala**: [GitHub](https://github.com/arturoa925) · [LinkedIn](https://linkedin.com/in/arturo-ayala-775493187)
