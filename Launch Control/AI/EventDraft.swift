import Foundation

/// A fully validated, model-agnostic description of an event to create.
/// Both the on-device language model and the keyword fallback produce this type,
/// so everything downstream (Siri intents, tests) deals with one shape.
struct EventDraft: Equatable {
    static let maxDayOffset = 365

    var title: String
    var dayOffset: Int
    var hour: Int?
    var minute: Int
    var category: String
    var notes: String
    var wantsReminder: Bool

    /// Cleans untrusted input (model output or parsed text) into a safe draft:
    /// trims text, clamps the offset to today...a year out, and only keeps
    /// categories the app actually has.
    init(title: String, dayOffset: Int, hour: Int? = nil, minute: Int = 0, category: String = "", notes: String = "", wantsReminder: Bool = false) {
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.dayOffset = min(max(dayOffset, 0), Self.maxDayOffset)
        self.hour = hour.flatMap { (0...23).contains($0) ? $0 : nil }
        self.minute = min(max(minute, 0), 59)
        self.wantsReminder = wantsReminder
        self.category = EventEditor.defaultCategories
            .first { $0.caseInsensitiveCompare(category.trimmingCharacters(in: .whitespaces)) == .orderedSame } ?? ""
        self.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The model never computes calendar dates itself, because LLMs are unreliable at
    /// date arithmetic. It only says "N days from today" and Swift does the math.
    func resolvedDate(calendar: Calendar = .current, now: Date = Date()) -> Date {
        calendar.date(byAdding: .day, value: dayOffset, to: now) ?? now
    }

    /// The time of day as a date on the event's day, or nil if the user gave no time.
    func resolvedTime(calendar: Calendar = .current, now: Date = Date()) -> Date? {
        guard let hour else { return nil }
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: resolvedDate(calendar: calendar, now: now))
    }

    static let defaultReminderHour = 9

    /// When to notify, or nil for no reminder. A stated time or an explicit "remind me" both
    /// ask for one; with no time it fires at 9 AM. A moment that has already passed gets none,
    /// since the system would never deliver it.
    func reminderDate(calendar: Calendar = .current, now: Date = Date()) -> Date? {
        guard wantsReminder || hour != nil else { return nil }
        let target = resolvedTime(calendar: calendar, now: now)
            ?? calendar.date(bySettingHour: Self.defaultReminderHour, minute: 0, second: 0,
                             of: resolvedDate(calendar: calendar, now: now))
        guard let target, target > now else { return nil }
        return target
    }

    func spokenWhen(calendar: Calendar = .current, now: Date = Date()) -> String {
        let day = spokenDay(calendar: calendar, now: now)
        guard let time = resolvedTime(calendar: calendar, now: now) else { return day }
        return "\(day) at \(time.formatted(.dateTime.hour().minute()))"
    }

    func spokenDay(calendar: Calendar = .current, now: Date = Date()) -> String {
        switch dayOffset {
        case 0: return "today"
        case 1: return "tomorrow"
        default:
            return resolvedDate(calendar: calendar, now: now)
                .formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        }
    }
}

/// Deterministic, offline parser used when Apple Intelligence is unavailable
/// (older hardware, model still downloading, user opted out) or the model errors.
/// It handles the common phrasings so Siri never just says "I can't do that".
enum EventDraftParser {
    private static let weekdays = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]

    private static let categoryKeywords: [(category: String, words: [String])] = [
        ("Health", ["gym", "workout", "doctor", "dentist", "run", "yoga", "therapy", "checkup"]),
        ("Education", ["study", "homework", "exam", "class", "lecture", "assignment", "quiz"]),
        ("Work", ["meeting", "email", "report", "client", "deadline", "standup", "interview"]),
        ("Social", ["dinner with", "birthday", "party", "friends", "drinks", "lunch with"]),
    ]

    static func parse(_ text: String, calendar: Calendar = .current, now: Date = Date()) -> EventDraft {
        var working = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var offset = 0

        if let (range, value) = dayPhrase(in: working, calendar: calendar, now: now) {
            offset = value
            working.removeSubrange(range)
        }

        var hour: Int?
        var minute = 0
        if let (range, h, m) = timePhrase(in: working) {
            hour = h
            minute = m
            working.removeSubrange(range)
        }

        // Tidy what's left once the date/time words are cut out, drop a trailing
        // "remind me", and treat anything after the first comma as notes.
        let normalized = working
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+,"#, with: ",", options: .regularExpression)
            .replacingOccurrences(of: #"[,\s]*\bremind me\b[,\s]*$"#, with: "", options: [.regularExpression, .caseInsensitive])
        let parts = normalized.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
        let title = cleanedTitle(parts.first.map(String.init) ?? "", fallback: text)
        let notes = parts.count > 1 ? String(parts[1]) : ""
        let wantsReminder = text.range(of: #"\bremind(er)?\b"#, options: [.regularExpression, .caseInsensitive]) != nil
        return EventDraft(title: title, dayOffset: offset, hour: hour, minute: minute,
                          category: category(for: title), notes: notes, wantsReminder: wantsReminder)
    }

    private static func dayPhrase(in text: String, calendar: Calendar, now: Date) -> (Range<String.Index>, Int)? {
        let fixed: [(pattern: String, offset: Int)] = [
            (#"\bday after tomorrow\b"#, 2),
            (#"\btomorrow\b"#, 1),
            (#"\b(today|tonight)\b"#, 0),
        ]
        for (pattern, offset) in fixed {
            if let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                return (range, offset)
            }
        }

        if let range = text.range(of: #"\bin \d{1,3} days?\b"#, options: [.regularExpression, .caseInsensitive]),
           let days = Int(text[range].filter(\.isNumber)) {
            return (range, days)
        }

        let today = calendar.component(.weekday, from: now) - 1 // 0 = Sunday
        for (index, name) in weekdays.enumerated() {
            let pattern = #"\b(?:(next|on)\s+)?"# + name + #"\b"#
            guard let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else { continue }
            var delta = (index - today + 7) % 7
            // "next Tuesday" said on a Tuesday means a week from now, not today.
            if delta == 0, text[range].lowercased().hasPrefix("next") { delta = 7 }
            return (range, delta)
        }
        return nil
    }

    /// "at 3pm", "3:30 pm", "at noon". Only 12-hour forms with am/pm (or noon), so a bare
    /// number like "3 sets of squats" is never mistaken for a time.
    private static func timePhrase(in text: String) -> (Range<String.Index>, Int, Int)? {
        if let range = text.range(of: #"\b(at\s+)?noon\b"#, options: [.regularExpression, .caseInsensitive]) {
            return (range, 12, 0)
        }
        let pattern = #"\b(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let whole = Range(match.range, in: text),
              let hourRange = Range(match.range(at: 1), in: text),
              let meridiemRange = Range(match.range(at: 3), in: text),
              var hour = Int(text[hourRange]), (1...12).contains(hour) else { return nil }
        let minute = Range(match.range(at: 2), in: text).flatMap { Int(text[$0]) } ?? 0
        guard (0...59).contains(minute) else { return nil }
        let isPM = text[meridiemRange].lowercased() == "pm"
        hour = (hour % 12) + (isPM ? 12 : 0)
        return (whole, hour, minute)
    }

    private static func cleanedTitle(_ text: String, fallback: String) -> String {
        var result = text
        let fillers = [#"^\s*(please\s+)?(add|schedule|create|plan|remind me to)\s+(an?\s+|the\s+)?"#,
                       #"\s+(to|on|for|by|at|before|until|from)\s*$"#,
                       #"\s+(to|on|for)\s+my\s+(list|plan|schedule)\s*$"#]
        for filler in fillers {
            if let range = result.range(of: filler, options: [.regularExpression, .caseInsensitive]) {
                result.removeSubrange(range)
            }
        }
        result = result
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))

        guard let first = result.first else { return fallback.trimmingCharacters(in: .whitespacesAndNewlines) }
        return first.uppercased() + result.dropFirst()
    }

    private static func category(for title: String) -> String {
        let lowered = title.lowercased()
        return categoryKeywords.first { entry in
            entry.words.contains { lowered.range(of: #"\b"# + NSRegularExpression.escapedPattern(for: $0) + #"\b"#, options: .regularExpression) != nil }
        }?.category ?? ""
    }
}
