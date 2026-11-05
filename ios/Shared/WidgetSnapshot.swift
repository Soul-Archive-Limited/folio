import Foundation

/// What Folio's widgets show (Batch J): a small snapshot the app writes to the App Group after
/// changes. Widgets never open the diary itself. Titles are left out entirely when the person
/// turned widget details off.
nonisolated struct WidgetSnapshot: Codable, Equatable, Sendable {
    struct Task: Codable, Equatable, Sendable, Identifiable {
        var id: UUID
        var title: String
        var dayKey: String
        var minutes: Int?
        var isDone: Bool
        /// Category colour as "RRGGBB" for light and dark; nil for none.
        var tintLight: String?
        var tintDark: String?
    }

    struct Day: Codable, Equatable, Sendable {
        var entries: Int = 0
        /// File name in the snapshot's thumbs folder.
        var photo: String?
        /// Category colours of the first pages, "RRGGBB|RRGGBB" (light|dark).
        var dots: [String] = []
        var openTasks: Int = 0
        var doneTasks: Int = 0
    }

    struct Month: Codable, Equatable, Sendable {
        var year: Int
        var month: Int
        /// The 42 grid days ("YYYY-MM-DD"), first weekday first.
        var grid: [String]
        var days: [String: Day]
    }

    var writtenAt: Date
    /// Greeting lines by period: early, morning, afternoon, evening, night.
    var greetings: [String: String]
    /// Open tasks before today, then today's and tomorrow's tasks.
    var tasks: [Task]
    var months: [Month]
    var showsDetails: Bool
    /// "On this day in 2025" for today, if any (no titles).
    var onThisDayYears: [String: Int] = [:]

    static let fileName = "widget-snapshot.json"

    static var url: URL? { AppGroup.folder("Widgets")?.appending(path: fileName) }
    static var thumbsFolder: URL? { AppGroup.folder("Widgets/thumbs") }

    static func load() -> WidgetSnapshot? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }

    func encoded() -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = .sortedKeys
        return try? encoder.encode(self)
    }

    /// The greeting period key for an hour (SPEC §4.2's periods).
    static func period(hour: Int) -> String {
        switch hour {
        case 4..<7: "early"
        case 7..<12: "morning"
        case 12..<17: "afternoon"
        case 17..<21: "evening"
        default: "night"
        }
    }

    /// Hours at which the greeting changes; the widget timeline adds an entry at each.
    static let periodStarts = [4, 7, 12, 17, 21]
}
