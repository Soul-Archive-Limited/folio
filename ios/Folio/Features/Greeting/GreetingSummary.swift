import SwiftUI

/// The numbers behind the greeting's summary line (SPEC §4.2). Zero parts are left out;
/// when every part is zero, a quiet line is shown instead.
struct GreetingSummary: Equatable, Sendable {
    var tasksToday = 0
    var tasksOverdue = 0
    var pagesThisWeek = 0
    /// Year of an entry written on this calendar day 1+ years ago, if any.
    var onThisDayYear: Int?

    static let empty = GreetingSummary()

    var isQuiet: Bool { tasksToday == 0 && tasksOverdue == 0 && pagesThisWeek == 0 }

    /// The summary as one `Text` with inline SF Symbols, or nil when quiet.
    var text: Text? {
        var parts: [Text] = []
        if tasksToday > 0 {
            parts.append(Text("\(Image(systemName: "checklist")) ^[\(tasksToday) task](inflect: true) today"))
        }
        if tasksOverdue > 0 {
            parts.append(Text("\(Image(systemName: "clock.badge.exclamationmark")) \(tasksOverdue) overdue"))
        }
        if pagesThisWeek > 0 {
            parts.append(Text("\(Image(systemName: "book.pages")) ^[\(pagesThisWeek) page](inflect: true) this week"))
        }
        guard var result = parts.first else { return nil }
        for part in parts.dropFirst() {
            result = Text("\(result)  ·  \(part)")
        }
        return result
    }
}
