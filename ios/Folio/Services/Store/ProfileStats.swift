import Foundation

/// Numbers for the Profile header and "Your archive" tiles (SPEC §6.9). No streaks.
nonisolated struct ProfileStats: Equatable, Sendable {
    var entries = 0
    var photos = 0
    var daysWrittenOn = 0
    var tasksDone = 0
    /// The earliest day the diary has an entry for, so old diaries moved in count
    /// (owner review, Batch C) — not the install or creation date.
    var writingSince: DayKey?
}

extension DiaryStore {
    func profileStats() -> ProfileStats {
        let entries = allEntries()
        return ProfileStats(
            entries: entries.count,
            photos: allPhotos().count,
            daysWrittenOn: Set(entries.map(\.dayKey)).count,
            tasksDone: allTasks().count { $0.isCompleted },
            writingSince: entries.compactMap(\.day).min()
        )
    }
}
