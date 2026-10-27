import Foundation

/// Journal state (SPEC §6.6): view mode and category filter, with month sections cached
/// per store revision so 10,000 entries don't regroup on every redraw.
@Observable
final class JournalModel {
    enum Mode: String, CaseIterable, Identifiable {
        case timeline, photos
        var id: Self { self }
    }

    var mode: Mode = .timeline
    /// Pushed entries; the floating "+" shows only while this is empty.
    var path: [UUID] = []
    /// Recently Deleted, pushed from the end of the timeline (SPEC §5.2).
    var showsTrash = false
    /// The floating "+" belongs to the Journal's root screen only.
    var isAtRoot: Bool { path.isEmpty && !showsTrash }
    var filter: Set<UUID> = []

    struct MonthSection: Identifiable {
        let month: MonthKey
        let entries: [Entry]
        var id: Int { month.id }
    }

    @ObservationIgnored private var cache: (revision: Int, filter: Set<UUID>, sections: [MonthSection])?

    func sections(store: DiaryStore) -> [MonthSection] {
        let revision = store.revision
        if let cache, cache.revision == revision, cache.filter == filter { return cache.sections }
        let entries = store.allEntries().filter(matches)
        var sections: [MonthSection] = []
        var current: [Entry] = []
        var currentMonth: MonthKey?
        for entry in entries {
            guard let month = entry.day?.monthKey else { continue }
            if month != currentMonth, let previous = currentMonth {
                sections.append(MonthSection(month: previous, entries: current))
                current = []
            }
            currentMonth = month
            current.append(entry)
        }
        if let currentMonth, !current.isEmpty { sections.append(MonthSection(month: currentMonth, entries: current)) }
        cache = (revision, filter, sections)
        return sections
    }

    func photos(store: DiaryStore) -> [EntryPhoto] {
        store.allPhotos().filter { photo in photo.entry.map(matches) ?? false }
    }

    func matches(_ entry: Entry) -> Bool {
        filter.isEmpty || entry.categoryID.map(filter.contains) == true
    }
}
