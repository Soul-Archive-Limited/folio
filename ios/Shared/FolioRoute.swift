import Foundation

/// Deep links into Folio (Batch J): widgets, controls, shortcuts. `folio://` only navigates —
/// it never writes anything — so another app opening one can't change the diary. With Lock
/// Folio on, the lock window covers wherever it lands.
nonisolated enum FolioRoute: Equatable, Sendable {
    case newEntry
    case newTask
    case dictate
    case today
    case onThisDay
    /// "YYYY-MM-DD"
    case day(String)
    case task(UUID)
    case search

    static let scheme = "folio"

    var url: URL {
        switch self {
        case .newEntry: URL(string: "folio://new-entry")!
        case .newTask: URL(string: "folio://new-task")!
        case .dictate: URL(string: "folio://dictate")!
        case .today: URL(string: "folio://today")!
        case .onThisDay: URL(string: "folio://on-this-day")!
        case .day(let raw): URL(string: "folio://day/\(raw)")!
        case .task(let id): URL(string: "folio://task/\(id.uuidString)")!
        case .search: URL(string: "folio://search")!
        }
    }

    init?(url: URL) {
        guard url.scheme == Self.scheme else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        switch url.host() {
        case "new-entry": self = .newEntry
        case "new-task": self = .newTask
        case "dictate": self = .dictate
        case "today": self = .today
        case "on-this-day": self = .onThisDay
        case "search": self = .search
        case "day":
            guard let raw = parts.first, raw.count == 10, raw.allSatisfy({ $0.isNumber || $0 == "-" }) else { return nil }
            self = .day(raw)
        case "task":
            guard let id = parts.first.flatMap(UUID.init(uuidString:)) else { return nil }
            self = .task(id)
        default: return nil
        }
    }
}
