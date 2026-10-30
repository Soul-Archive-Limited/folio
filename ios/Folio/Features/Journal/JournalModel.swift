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
    /// Months the person opened or closed themselves, by `MonthKey.id` (Batch I). Everything
    /// else follows the default: this month and last month open, older months closed.
    private(set) var foldOverrides: [Int: Bool]
    @ObservationIgnored private let defaults: UserDefaults
    static let foldKey = "journalMonthFolds"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.dictionary(forKey: Self.foldKey) as? [String: Bool] ?? [:]
        foldOverrides = Dictionary(uniqueKeysWithValues: stored.compactMap { key, value in Int(key).map { ($0, value) } })
    }

    func isOpen(_ month: MonthKey, today: DayKey) -> Bool {
        foldOverrides[month.id] ?? Self.opensByDefault(month, today: today)
    }

    static func opensByDefault(_ month: MonthKey, today: DayKey) -> Bool {
        let current = today.monthKey
        return month >= current.adding(months: -1)
    }

    func toggle(_ month: MonthKey, today: DayKey) {
        let open = !isOpen(month, today: today)
        // Back to the default: forget the override, so the list keeps up as months go by.
        foldOverrides[month.id] = open == Self.opensByDefault(month, today: today) ? nil : open
        defaults.set(Dictionary(uniqueKeysWithValues: foldOverrides.map { (String($0.key), $0.value) }), forKey: Self.foldKey)
    }

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
        var currentPrefix: Substring?
        // Group on the "YYYY-MM" prefix: parsing a DayKey per entry showed in the 10,000-entry profile.
        func close() {
            if let first = current.first, let month = first.day?.monthKey { sections.append(MonthSection(month: month, entries: current)) }
        }
        for entry in entries {
            let prefix = entry.dayKey.prefix(7)
            if prefix != currentPrefix {
                close()
                current = []
                currentPrefix = prefix
            }
            current.append(entry)
        }
        close()
        cache = (revision, filter, sections)
        return sections
    }

    @ObservationIgnored private var photoCache: (revision: Int, filter: Set<UUID>, photos: [EntryPhoto])?

    /// Cached per store revision and filter, like the sections: building the list touches every
    /// photo's entry, which the Batch I profile showed on each redraw of the Photos view.
    func photos(store: DiaryStore) -> [EntryPhoto] {
        let revision = store.revision
        if let photoCache, photoCache.revision == revision, photoCache.filter == filter { return photoCache.photos }
        let photos = store.allPhotos().filter { photo in photo.entry.map(matches) ?? false }
        photoCache = (revision, filter, photos)
        return photos
    }

    func matches(_ entry: Entry) -> Bool {
        filter.isEmpty || entry.categoryID.map(filter.contains) == true
    }
}
