import Foundation

/// Numbers for the Profile header and "Your archive" tiles (SPEC §6.9). No streaks.
nonisolated struct ProfileStats: Equatable, Sendable {
    var entries = 0
    var photos = 0
    var daysWrittenOn = 0
    var tasksDone = 0
    /// When the first entry was written in Folio (not the day it's for).
    var writingSince: Date?
}

extension DiaryStore {
    func profileStats() -> ProfileStats {
        let entries = allEntries()
        return ProfileStats(
            entries: entries.count,
            photos: allPhotos().count,
            daysWrittenOn: Set(entries.map(\.dayKey)).count,
            tasksDone: allTasks().count { $0.isCompleted },
            writingSince: entries.map(\.createdAt).min()
        )
    }
}
