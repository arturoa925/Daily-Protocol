import Foundation

/// A fully validated, model-agnostic description of an event to create.
/// Both the on-device language model and the keyword fallback produce this type,
/// so everything downstream (Siri intents, tests) deals with one shape.
struct EventDraft: Equatable {
    static let maxDayOffset = 365

    var title: String
    var dayOffset: Int
    var category: String
    var notes: String

    /// Cleans untrusted input (model output or parsed text) into a safe draft:
    /// trims text, clamps the offset to today...a year out, and only keeps
    /// categories the app actually has.
    init(title: String, dayOffset: Int, category: String = "", notes: String = "") {
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.dayOffset = min(max(dayOffset, 0), Self.maxDayOffset)
        self.category = EventEditor.defaultCategories
            .first { $0.caseInsensitiveCompare(category.trimmingCharacters(in: .whitespaces)) == .orderedSame } ?? ""
        self.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The model never computes calendar dates itself, because LLMs are unreliable at
    /// date arithmetic. It only says "N days from today" and Swift does the math.
    func resolvedDate(calendar: Calendar = .current, now: Date = Date()) -> Date {
        calendar.date(byAdding: .day, value: dayOffset, to: now) ?? now
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

        let title = cleanedTitle(working, fallback: text)
        return EventDraft(title: title, dayOffset: offset, category: category(for: title))
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

    private static func cleanedTitle(_ text: String, fallback: String) -> String {
        var result = text
        let fillers = [#"^\s*(please\s+)?(add|schedule|create|plan|remind me to)\s+(an?\s+|the\s+)?"#,
                       #"\s+(to|on|for)\s*$"#,
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
