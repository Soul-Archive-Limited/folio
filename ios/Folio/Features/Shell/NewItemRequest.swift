import Foundation

/// What the "+" button, a day's long-press menu or the day panel asked to create.
enum NewItemRequest: Identifiable, Hashable {
    case entry(DayKey)
    case task(DayKey?)
    case dictation(DayKey)

    var id: String {
        switch self {
        case .entry(let day): "entry-\(day.rawValue)"
        case .task(let day): "task-\(day?.rawValue ?? "undated")"
        case .dictation(let day): "dictation-\(day.rawValue)"
        }
    }
}
