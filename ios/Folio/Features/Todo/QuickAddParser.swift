import Foundation

/// Reads a date and time out of a quick-add line (SPEC §6.7, natural dates in Batch I):
/// "Call Mum tomorrow 6pm" is "Call Mum", tomorrow at 18:00. Recognised phrases:
/// - days: today, tonight, tomorrow (tmrw), day after tomorrow, in/after N days|weeks|months
///   (digits or a…twelve), next week, next month, this weekend / weekend, [on|this|next] Monday…
///   (or Mon…), on 5 Nov, 5th of November, November 5, 5/11 (day first, or month first in the
///   US), with an optional year;
/// - times: 6pm, 6:30 pm, 18:30, 18.30, at 7, noon / midday, morning, afternoon, evening.
/// Phrases count only at the start or end of the line, so "Today's papers" or "Read Monday
/// notes" stay as typed. A bare "at 7" is the next 7 o'clock that hasn't passed (morning or
/// evening); a time with no day is today, or tomorrow once it has passed. "Next Monday" is the
/// first Monday after today; "Monday" / "on Monday" is today when it is Monday.
nonisolated enum QuickAddParser {
    struct Result: Equatable {
        let title: String
        let day: DayKey?
        var minutesFromMidnight: Int?
    }

    /// Back-compatible form without a clock: dates only resolve against `today`.
    static func parse(_ text: String, today: DayKey) -> Result {
        parse(text, today: today, minutesNow: 0, monthFirst: false)
    }

    static func parse(_ text: String, now: Date, calendar: Calendar, locale: Locale = .current) -> Result {
        let today = DayKey(date: now, calendar: calendar)
        let parts = calendar.dateComponents([.hour, .minute], from: now)
        return parse(text, today: today, minutesNow: (parts.hour ?? 0) * 60 + (parts.minute ?? 0),
                     monthFirst: locale.region == .unitedStates)
    }

    static func parse(_ text: String, today: DayKey, minutesNow: Int, monthFirst: Bool) -> Result {
        var rest = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var day: DayKey?
        var time: TimeMatch?
        // Up to three phrases (e.g. "next Monday" + "at 7"), peeled from either end.
        for _ in 0..<3 {
            guard let match = peel(rest, today: today, monthFirst: monthFirst, wantsDay: day == nil, wantsTime: time == nil) else { break }
            let remaining = match.remaining.trimmingCharacters(in: .whitespacesAndNewlines.union(.init(charactersIn: ",")))
            // Never eat the whole line: "Tomorrow" alone is a task called "Tomorrow".
            guard !remaining.isEmpty else { break }
            rest = remaining
            if let found = match.day { day = found }
            if let found = match.time { time = found }
        }
        guard day != nil || time != nil else { return Result(title: rest, day: nil, minutesFromMidnight: nil) }
        var resolvedDay = day ?? today
        var minutes: Int?
        if let time {
            let candidates = time.candidates
            if resolvedDay == today {
                if let future = candidates.first(where: { $0 > minutesNow }) {
                    minutes = future
                } else {
                    minutes = candidates.first
                    if day == nil { resolvedDay = today.adding(days: 1) }
                }
            } else {
                minutes = time.preferred
            }
        }
        return Result(title: rest, day: resolvedDay, minutesFromMidnight: minutes)
    }

    // MARK: - Matching

    struct TimeMatch: Equatable {
        /// Possible readings in minutes, in the order to try ("at 7" → 07:00, 19:00).
        let candidates: [Int]
        /// The reading for another day: 1–6 o'clock → afternoon, 7–11 → morning.
        let preferred: Int
    }

    private struct Peeled {
        let remaining: String
        let day: DayKey?
        let time: TimeMatch?
    }

    private static func peel(_ text: String, today: DayKey, monthFirst: Bool, wantsDay: Bool, wantsTime: Bool) -> Peeled? {
        for anchoredAtEnd in [true, false] {
            if wantsTime, let (range, time) = firstMatch(timePatterns, in: text, atEnd: anchoredAtEnd, read: { readTime($0, $1) }) {
                return Peeled(remaining: text.replacingCharacters(in: range, with: " "), day: nil, time: time)
            }
            if wantsDay, let (range, found) = firstMatch(dayPatterns, in: text, atEnd: anchoredAtEnd, read: { readDay($0, $1, today: today, monthFirst: monthFirst) }) {
                // "tonight" brings a time with it; "tomorrow morning" is two phrases.
                return Peeled(remaining: text.replacingCharacters(in: range, with: " "), day: found.day, time: found.time)
            }
        }
        return nil
    }

    private static func firstMatch<T>(_ patterns: [(Kind, NSRegularExpression)], in text: String, atEnd: Bool,
                                      read: (Kind, [String?]) -> T?) -> (Range<String.Index>, T)? {
        let ns = text as NSString
        for (kind, pattern) in patterns {
            let anchored = try? NSRegularExpression(
                pattern: atEnd ? "(?:^|(?<=[\\s,]))(?:\(pattern.pattern))[.!]?$" : "^(?:\(pattern.pattern))(?=$|[\\s,])",
                options: [.caseInsensitive])
            guard let anchored, let match = anchored.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
                  let range = Range(match.range, in: text) else { continue }
            let groups = (1..<match.numberOfRanges).map { index -> String? in
                let r = match.range(at: index)
                return r.location == NSNotFound ? nil : ns.substring(with: r).lowercased()
            }
            if let value = read(kind, groups) { return (range, value) }
        }
        return nil
    }

    // MARK: - Days

    private enum Kind {
        case dayAfterTomorrow, todayOrTonight, tomorrow, relative, nextWeekOrMonth, weekend, weekday
        case dayMonth, monthDay, numeric
        case clock, clock24, bareHour, partOfDay
    }

    private struct DayMatch {
        let day: DayKey
        var time: TimeMatch?
    }

    private static let weekdayNames = "(mon(?:day)?|tue(?:s(?:day)?)?|wed(?:nesday)?|thu(?:r(?:s(?:day)?)?)?|fri(?:day)?|sat(?:urday)?|sun(?:day)?)"
    private static let monthNames = "(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|june?|july?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)"
    private static let count = "(\\d{1,3}|a|an|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)"

    private static let dayPatterns: [(Kind, NSRegularExpression)] = [
        (.dayAfterTomorrow, "day after tomorrow"),
        (.todayOrTonight, "(today|tonight)"),
        (.tomorrow, "(?:tomorrow|tmrw|tmr)"),
        (.relative, "(?:in|after) \(count) (days?|weeks?|months?)"),
        (.nextWeekOrMonth, "next (week|month)"),
        (.weekend, "(?:this )?weekend"),
        // Full names on their own; short ones ("sun", "wed") only after on/this/next.
        (.weekday, "(?:on )?(?:(next|this) )?(monday|tuesday|wednesday|thursday|friday|saturday|sunday)"),
        (.weekday, "(?:on |(next|this) )\(weekdayNames)"),
        (.dayMonth, "(?:on )?(?:the )?(\\d{1,2})(?:st|nd|rd|th)?(?: of)? \(monthNames),?(?: (\\d{4}))?"),
        (.monthDay, "(?:on )?\(monthNames) (\\d{1,2})(?:st|nd|rd|th)?,?(?: (\\d{4}))?"),
        (.numeric, "(?:on )?(\\d{1,2})[/-](\\d{1,2})(?:[/-](\\d{2}|\\d{4}))?"),
        // Dots only with a year, so "5.30" stays a time.
        (.numeric, "(?:on )?(\\d{1,2})\\.(\\d{1,2})\\.(\\d{2}|\\d{4})"),
    ].compactMap { kind, pattern in (try? NSRegularExpression(pattern: pattern)).map { (kind, $0) } }

    private static func readDay(_ kind: Kind, _ g: [String?], today: DayKey, monthFirst: Bool) -> DayMatch? {
        switch kind {
        case .dayAfterTomorrow:
            return DayMatch(day: today.adding(days: 2))
        case .todayOrTonight:
            guard g.first == "tonight" else { return DayMatch(day: today) }
            return DayMatch(day: today, time: TimeMatch(candidates: [20 * 60], preferred: 20 * 60))
        case .tomorrow:
            return DayMatch(day: today.adding(days: 1))
        case .relative:
            guard let n = g[0].flatMap(number), n > 0, n <= 400, let unit = g[1] else { return nil }
            if unit.hasPrefix("day") { return DayMatch(day: today.adding(days: n)) }
            if unit.hasPrefix("week") { return DayMatch(day: today.adding(days: 7 * n)) }
            return addingMonths(n, to: today).map { DayMatch(day: $0) }
        case .nextWeekOrMonth:
            return g[0] == "week" ? DayMatch(day: today.adding(days: 7)) : addingMonths(1, to: today).map { DayMatch(day: $0) }
        case .weekend:
            // Saturday, or today when it already is the weekend.
            let wd = today.weekday
            return DayMatch(day: wd == 7 || wd == 1 ? today : today.adding(days: 7 - wd))
        case .weekday:
            guard let target = g[1].flatMap(weekday) else { return nil }
            var ahead = (target - today.weekday + 7) % 7
            if g[0] == "next", ahead == 0 { ahead = 7 }
            return DayMatch(day: today.adding(days: ahead))
        case .dayMonth, .monthDay:
            let (dayText, monthText) = kind == .dayMonth ? (g[0], g[1]) : (g[1], g[0])
            guard let d = dayText.flatMap({ Int($0) }), let m = monthText.flatMap(month) else { return nil }
            return dated(day: d, month: m, year: g[2].flatMap { Int($0) }, today: today).map { DayMatch(day: $0) }
        case .numeric:
            guard let a = g[0].flatMap({ Int($0) }), let b = g[1].flatMap({ Int($0) }) else { return nil }
            let (d, m) = monthFirst ? (b, a) : (a, b)
            var year = g[2].flatMap { Int($0) }
            if let y = year, y < 100 { year = 2000 + y }
            return dated(day: d, month: m, year: year, today: today).map { DayMatch(day: $0) }
        default:
            return nil
        }
    }

    /// A day and month (and maybe year); without a year, the next time that date comes round.
    private static func dated(day: Int, month: Int, year: Int?, today: DayKey) -> DayKey? {
        guard (1...12).contains(month), (1...31).contains(day) else { return nil }
        if let year {
            guard let key = DayKey(year: year, month: month, day: day), key.month == month, key.day == day else { return nil }
            return key
        }
        for y in [today.year, today.year + 1] {
            if let key = DayKey(year: y, month: month, day: day), key.month == month, key.day == day, !(key < today) { return key }
        }
        return nil
    }

    private static func addingMonths(_ n: Int, to day: DayKey) -> DayKey? {
        let total = day.year * 12 + (day.month - 1) + n
        let year = total / 12, month = total % 12 + 1
        let lastDay = MonthKey(year: year, month: month).dayCount
        return DayKey(year: year, month: month, day: min(day.day, lastDay))
    }

    private static func weekday(_ name: String) -> Int? {
        let order = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]
        return order.firstIndex { name.hasPrefix($0) }.map { $0 + 1 }
    }

    private static func month(_ name: String) -> Int? {
        let order = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        return order.firstIndex { name.hasPrefix($0) }.map { $0 + 1 }
    }

    private static func number(_ word: String) -> Int? {
        if let n = Int(word) { return n }
        let words = ["a": 1, "an": 1, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7,
                     "eight": 8, "nine": 9, "ten": 10, "eleven": 11, "twelve": 12]
        return words[word]
    }

    // MARK: - Times

    private static let timePatterns: [(Kind, NSRegularExpression)] = [
        (.clock, "(?:at )?(\\d{1,2})(?:[:.](\\d{2}))? ?(am|pm|a\\.m\\.|p\\.m\\.)"),
        (.clock24, "(?:at )?(\\d{1,2})[:.](\\d{2})"),
        (.bareHour, "at (\\d{1,2})"),
        (.partOfDay, "(?:at |in the |this )?(noon|midday|morning|afternoon|evening)"),
    ].compactMap { kind, pattern in (try? NSRegularExpression(pattern: pattern)).map { (kind, $0) } }

    private static func readTime(_ kind: Kind, _ g: [String?]) -> TimeMatch? {
        func fixed(_ minutes: Int) -> TimeMatch { TimeMatch(candidates: [minutes], preferred: minutes) }
        switch kind {
        case .partOfDay:
            switch g[0] {
            case "noon", "midday": return fixed(12 * 60)
            case "morning": return fixed(9 * 60)
            case "afternoon": return fixed(15 * 60)
            default: return fixed(18 * 60)
            }
        case .clock:
            guard let hour = g[0].flatMap({ Int($0) }), (1...12).contains(hour) else { return nil }
            let minute = g[1].flatMap { Int($0) } ?? 0
            guard (0...59).contains(minute) else { return nil }
            let h = (hour % 12) + ((g[2] ?? "").hasPrefix("p") ? 12 : 0)
            return fixed(h * 60 + minute)
        case .clock24, .bareHour:
            guard let hour = g[0].flatMap({ Int($0) }), (0...23).contains(hour) else { return nil }
            let minute = kind == .clock24 ? (g[1].flatMap { Int($0) } ?? 0) : 0
            guard (0...59).contains(minute) else { return nil }
            if hour == 0 || hour >= 12 { return fixed(hour * 60 + minute) }
            // 1–11 with no am/pm: morning or evening, whichever comes next.
            let morning = hour * 60 + minute, evening = (hour + 12) * 60 + minute
            return TimeMatch(candidates: [morning, evening], preferred: hour <= 6 ? evening : morning)
        default:
            return nil
        }
    }
}

nonisolated extension QuickAddParser.Result {
    /// The live chip's words: "Tomorrow · 18:00", "Mon 2 Nov", "Today · 19:30".
    func summary(today: DayKey) -> String? {
        guard let day else { return nil }
        let dayText: String
        switch today.days(to: day) {
        case 0: dayText = String(localized: "Today")
        case 1: dayText = String(localized: "Tomorrow")
        default:
            let style = Date.FormatStyle(timeZone: .gmt).weekday(.abbreviated).day().month(.abbreviated)
            dayText = day.year == today.year ? day.utcDate.formatted(style) : day.utcDate.formatted(style.year())
        }
        guard let minutes = minutesFromMidnight else { return dayText }
        let time = String(format: "%02d:%02d", minutes / 60, minutes % 60)
        return "\(dayText) · \(time)"
    }
}
