import Foundation

/// Ticks made on a widget (Batch J). The widget can't open the diary, so it records the tick
/// here and updates its own snapshot at once; the app applies the queue the next time it runs
/// (opening, coming to the foreground, background refresh) — a normal local edit that syncs.
nonisolated enum WidgetActionQueue {
    struct Action: Codable, Equatable, Sendable {
        var taskID: UUID
        var isDone: Bool
        var at: Date
    }

    private static var url: URL? { AppGroup.folder("Widgets")?.appending(path: "pending-ticks.json") }

    static func append(_ action: Action) {
        coordinate { url in
            var actions = read(url)
            // The last tick of a task wins.
            actions.removeAll { $0.taskID == action.taskID }
            actions.append(action)
            write(actions, to: url)
        }
    }

    /// Returns and clears every pending action.
    static func drain() -> [Action] {
        var drained: [Action] = []
        coordinate { url in
            drained = read(url)
            if !drained.isEmpty { try? FileManager.default.removeItem(at: url) }
        }
        return drained
    }

    private static func coordinate(_ body: (URL) -> Void) {
        guard let url else { return }
        var error: NSError?
        NSFileCoordinator().coordinate(writingItemAt: url, options: [], error: &error) { body($0) }
    }

    private static func read(_ url: URL) -> [Action] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return (try? decoder.decode([Action].self, from: data)) ?? []
    }

    private static func write(_ actions: [Action], to url: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        // At most a few hundred ticks between app launches; cap so a stuck queue stays small.
        guard let data = try? encoder.encode(Array(actions.suffix(500))) else { return }
        try? AppGroup.write(data, to: url)
    }
}
