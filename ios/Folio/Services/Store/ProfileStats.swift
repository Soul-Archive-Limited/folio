import Foundation
import SwiftData

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
    /// Synchronous stats (tests, export). Counts in the database instead of loading every entry
    /// and photo: the old version took ~1.8 s of main-thread time opening Profile on a
    /// 10,000-entry diary (Batch I, Time Profiler). Cached until the next write.
    func profileStats() -> ProfileStats {
        if let cached = profileStatsCache, cached.revision == revision { return cached.stats }
        let stats = ProfileStatsQuery.compute(in: context)
        profileStatsCache = (revision, stats)
        profileStatsValue = stats
        return stats
    }

    /// Recomputes the stats off the main thread after a write (Profile shows the last known
    /// numbers meanwhile), so opening Profile never stalls.
    func refreshProfileStats() async {
        let target = revision
        if let cached = profileStatsCache, cached.revision == target {
            if profileStatsValue != cached.stats { profileStatsValue = cached.stats }
            return
        }
        let container = context.container
        let stats = await Task.detached(priority: .userInitiated) {
            ProfileStatsQuery.compute(in: ModelContext(container))
        }.value
        guard revision == target else { return }
        profileStatsCache = (target, stats)
        profileStatsValue = stats
    }
}

/// The queries behind `ProfileStats`; runs on any context.
nonisolated enum ProfileStatsQuery {
    static func compute(in context: ModelContext) -> ProfileStats {
        let live = #Predicate<Entry> { !$0.isTombstone && $0.trashedAt == nil }
        var days = FetchDescriptor<Entry>(predicate: live)
        days.propertiesToFetch = [\.dayKey]
        let dayKeys = Set(((try? context.fetch(days)) ?? []).map(\.dayKey))
        var earliest = FetchDescriptor<Entry>(predicate: live, sortBy: [SortDescriptor(\.dayKey)])
        earliest.fetchLimit = 1
        let photos = FetchDescriptor<EntryPhoto>(predicate: #Predicate {
            !$0.isTombstone && $0.entry?.isTombstone == false && $0.entry?.trashedAt == nil
        })
        let done = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.isCompleted && !$0.isTombstone && $0.trashedAt == nil })
        return ProfileStats(
            entries: (try? context.fetchCount(FetchDescriptor<Entry>(predicate: live))) ?? 0,
            photos: (try? context.fetchCount(photos)) ?? 0,
            daysWrittenOn: dayKeys.count,
            tasksDone: (try? context.fetchCount(done)) ?? 0,
            writingSince: (try? context.fetch(earliest))?.first?.day
        )
    }
}
