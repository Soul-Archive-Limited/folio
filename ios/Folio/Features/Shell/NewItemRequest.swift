import Foundation

/// What the "+" button, a day's long-press menu or the day panel asked to create.
enum NewItemRequest: Identifiable, Hashable {
    case entry(DayKey)
    /// A new task; `title` and `minutes` carry what was typed into the To-do quick-add bar.
    case task(DayKey?, title: String = "", minutes: Int? = nil)
    case dictation(DayKey)
    /// Edit an existing entry (opens the composer at the large detent).
    case editEntry(UUID)
    /// "Write for a past day" (SPEC §6.6): a new entry with the date picker already open.
    case pastEntry
    /// The "Continue your draft" pill (Batch I): opens the draft's composer with it restored.
    case resumeDraft

    var id: String {
        switch self {
        case .entry(let day): "entry-\(day.rawValue)"
        case .task(let day, _, _): "task-\(day?.rawValue ?? "undated")"
        case .dictation(let day): "dictation-\(day.rawValue)"
        case .editEntry(let id): "edit-\(id.uuidString)"
        case .pastEntry: "past-entry"
        case .resumeDraft: "resume-draft"
        }
    }
}
