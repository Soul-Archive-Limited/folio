import AppIntents
import Foundation

/// "Add a task in Folio" (Siri, Shortcuts, Action Button): adds it without opening the app
/// (Batch J). Runs in Folio's own process, on the local store, so it works offline and syncs
/// like any other edit. Needs the iPhone unlocked (the store is protected while locked).
struct AddTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Task"
    static let description = IntentDescription("Adds a task to Folio, on a day if you give one.")
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Task", requestValueDialog: "What's the task?")
    var title: String

    @Parameter(title: "Date")
    var date: Date?

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$title) on \(\.$date)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let store = AppServices.store else { throw AddTaskError.unavailable }
        let calendar = Calendar.current
        let day = date.map { DayKey(date: $0, calendar: calendar) }
        // Midnight means "a day, no time" (Siri resolves "tomorrow" that way).
        let minutes = date.flatMap { date -> Int? in
            let parts = calendar.dateComponents([.hour, .minute], from: date)
            let total = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            return total == 0 ? nil : total
        }
        let trimmed = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(TaskItem.titleLengths.upperBound))
        do {
            try store.createTask(title: trimmed, day: day, minutesFromMidnight: minutes)
        } catch {
            throw AddTaskError.empty
        }
        guard let day else { return .result(dialog: "Added “\(trimmed)”.") }
        let when = day.utcDate.formatted(Date.FormatStyle(timeZone: .gmt).weekday(.abbreviated).day().month(.abbreviated))
        return .result(dialog: "Added “\(trimmed)” for \(when).")
    }
}

enum AddTaskError: Error, CustomLocalizedStringResourceConvertible {
    case unavailable, empty

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .unavailable: "Folio isn't ready yet. Try again in a moment."
        case .empty: "The task needs a title."
        }
    }
}
