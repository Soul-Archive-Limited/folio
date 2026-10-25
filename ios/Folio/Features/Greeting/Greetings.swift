import Foundation

/// The greeting pool (SPEC §4.2). All strings are localisable.
enum Greetings {
    static func pool(for period: GreetingPeriod) -> [Greeting] {
        switch period {
        case .early: early
        case .morning: morning
        case .afternoon: afternoon
        case .evening: evening
        case .night: night
        }
    }

    static let early: [Greeting] = [
        Greeting(id: "early.sun", named: { String(localized: "Up with the sun, \($0).") }, unnamed: { String(localized: "Up with the sun.") }),
        Greeting(id: "early.start", named: { String(localized: "Early start, \($0).") }, unnamed: { String(localized: "Early start.") }),
        Greeting(id: "early.quiet", named: { String(localized: "The world's still quiet, \($0).") }, unnamed: { String(localized: "The world's still quiet.") }),
        Greeting(id: "early.light", named: { String(localized: "First light, \($0).") }, unnamed: { String(localized: "First light.") }),
        Greeting(id: "early.page", named: { String(localized: "Fresh page, \($0).") }, unnamed: { String(localized: "Fresh page.") }),
    ]

    static let morning: [Greeting] = [
        Greeting(id: "morning.good", named: { String(localized: "Good morning, \($0).") }, unnamed: { String(localized: "Good morning.") }),
        Greeting(id: "morning.coffee", named: { String(localized: "Morning, \($0). Coffee first?") }, unnamed: { String(localized: "Morning. Coffee first?") }),
        Greeting(id: "morning.newday", named: { String(localized: "A new day, \($0).") }, unnamed: { String(localized: "A new day.") }),
        Greeting(id: "morning.unwritten", named: { String(localized: "Hello, \($0). Today's unwritten.") }, unnamed: { String(localized: "Hello. Today's unwritten.") }),
        Greeting(id: "morning.rise", named: { String(localized: "Rise and write, \($0).") }, unnamed: { String(localized: "Rise and write.") }),
        Greeting(id: "morning.light", named: { String(localized: "Morning light, \($0).") }, unnamed: { String(localized: "Morning light.") }),
    ]

    static let afternoon: [Greeting] = [
        Greeting(id: "afternoon.good", named: { String(localized: "Good afternoon, \($0).") }, unnamed: { String(localized: "Good afternoon.") }),
        Greeting(id: "afternoon.going", named: { String(localized: "Hey \($0), how's the day going?") }, unnamed: { String(localized: "Hey, how's the day going?") }),
        Greeting(id: "afternoon.halfway", named: { String(localized: "Halfway there, \($0).") }, unnamed: { String(localized: "Halfway there.") }),
        Greeting(id: "afternoon.plain", named: { String(localized: "Afternoon, \($0).") }, unnamed: { String(localized: "Afternoon.") }),
        Greeting(id: "afternoon.pause", named: { String(localized: "Taking a pause, \($0)?") }, unnamed: { String(localized: "Taking a pause?") }),
    ]

    static let evening: [Greeting] = [
        Greeting(id: "evening.good", named: { String(localized: "Good evening, \($0).") }, unnamed: { String(localized: "Good evening.") }),
        Greeting(id: "evening.today", named: { String(localized: "Evening, \($0). How was today?") }, unnamed: { String(localized: "Evening. How was today?") }),
        Greeting(id: "evening.back", named: { String(localized: "Welcome back, \($0).") }, unnamed: { String(localized: "Welcome back.") }),
        Greeting(id: "evening.winding", named: { String(localized: "Winding down, \($0)?") }, unnamed: { String(localized: "Winding down?") }),
        Greeting(id: "evening.written", named: { String(localized: "The day's almost written, \($0).") }, unnamed: { String(localized: "The day's almost written.") }),
    ]

    static let night: [Greeting] = [
        Greeting(id: "night.still", named: { String(localized: "Still up, \($0)?") }, unnamed: { String(localized: "Still up?") }),
        Greeting(id: "night.thoughts", named: { String(localized: "Late thoughts, \($0)?") }, unnamed: { String(localized: "Late thoughts?") }),
        Greeting(id: "night.good", named: { String(localized: "Good night, \($0).") }, unnamed: { String(localized: "Good night.") }),
        Greeting(id: "night.quiet", named: { String(localized: "Quiet hours, \($0).") }, unnamed: { String(localized: "Quiet hours.") }),
        Greeting(id: "night.ideas", named: { String(localized: "The best ideas come late, \($0).") }, unnamed: { String(localized: "The best ideas come late.") }),
    ]

    // MARK: Specials (1-in-3 when they apply)

    static func newYear() -> Greeting {
        Greeting(id: "special.newyear", named: { String(localized: "Happy New Year, \($0).") }, unnamed: { String(localized: "Happy New Year.") })
    }

    static func firstOfMonth(monthName: String) -> Greeting {
        Greeting(id: "special.month", named: { _ in String(localized: "Hello, \(monthName).") }, unnamed: { String(localized: "Hello, \(monthName).") })
    }

    static func onThisDay(year: Int) -> Greeting {
        let yearText = year.formatted(.number.grouping(.never))
        return Greeting(
            id: "special.onthisday",
            named: { _ in String(localized: "On this day in \(yearText), you wrote something.") },
            unnamed: { String(localized: "On this day in \(yearText), you wrote something.") }
        )
    }

    // MARK: Quiet summaries (shown when every summary count is zero)

    static let quietSummaries: [String] = [
        String(localized: "Nothing due. Just you and the page."),
        String(localized: "A clear day ahead."),
        String(localized: "No tasks. Plenty of room."),
    ]
}
