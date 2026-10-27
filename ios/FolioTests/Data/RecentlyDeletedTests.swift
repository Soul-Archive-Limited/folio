import Foundation
import SwiftData
import Testing
@testable import Folio

@MainActor
@Suite("Recently Deleted (SPEC §5.2)")
struct RecentlyDeletedTests {
    let container: ModelContainer
    let store: DiaryStore
    let clock: Clock
    let defaults: UserDefaults

    final class Clock {
        var now: Date
        init(_ now: Date) { self.now = now }
        func advance(days: Double) { now = now.addingTimeInterval(days * 86_400) }
    }

    init() throws {
        container = try FolioPersistence.makeContainer(inMemory: true)
        let clock = Clock(TestCalendar.date(2026, 10, 27, 9))
        self.clock = clock
        defaults = try #require(UserDefaults(suiteName: "trash-\(UUID().uuidString)"))
        store = DiaryStore(context: container.mainContext, calendar: TestCalendar.london, now: { clock.now },
                           trashClockDefaults: defaults)
    }

    static let photo = ProcessedPhoto(imageData: Data([1, 2]), thumbnailData: Data([3]), pixelWidth: 4, pixelHeight: 3,
                                      imageType: "public.heic", displayData: Data([4]))

    @Test("A trashed entry, its photos and a trashed task disappear from every view and count")
    func trashHidesEverywhere() throws {
        let today = store.today
        let lastYear = try #require(DayKey(year: today.year - 1, month: today.month, day: today.day))
        let travel = try store.createCategory(name: "Travel", color: .ocean)
        let entry = try store.createEntry(title: "Lisbon", day: today, categoryID: travel.id)
        _ = try store.addPhoto(Self.photo, to: entry)
        let old = try store.createEntry(title: "A year ago", day: lastYear)
        let task = try store.createTask(title: "Pack", day: today, categoryID: travel.id)

        store.trash(entry)
        store.trash(task)

        #expect(store.entries(on: today).isEmpty)
        #expect(store.tasks(on: today).isEmpty)
        #expect(store.allEntries().map(\.id) == [old.id])
        #expect(store.allTasks().isEmpty)
        #expect(store.allPhotos().isEmpty)
        #expect(store.markers(for: today.monthKey, firstWeekday: 2)[today] == nil, "no calendar marker")
        #expect(store.monthsWithEntries(in: today.year).isEmpty, "no Jump-sheet dot")
        #expect(store.entriesOnSameDay(as: lastYear, excluding: old.id).isEmpty)
        #expect(store.entry(id: entry.id) == nil && store.task(id: task.id) == nil)
        #expect(store.usage(of: travel) == CategoryUsage(entries: 0, tasks: 0))
        let summary = store.greetingSummary()
        #expect(summary.tasksToday == 0 && summary.pagesThisWeek == 0)
        let stats = store.profileStats()
        #expect(stats.entries == 1 && stats.photos == 0 && stats.daysWrittenOn == 1)
        #expect(JournalModel().sections(store: store).flatMap(\.entries).map(\.id) == [old.id])
        #expect(TodoModel().sections(from: store.allTasks(), today: today).active.isEmpty)

        #expect(store.trashCount == 2)
        #expect(store.trashedEntries().map(\.id) == [entry.id])
        #expect(store.trashedTasks().map(\.id) == [task.id])
        #expect(entry.orderedPhotos.count == 1, "photos go to the trash with their entry")
    }

    @Test("Restore puts an entry back on the same day, with its category and photos")
    func restoreEntry() throws {
        let day = try #require(DayKey(rawValue: "2026-10-20"))
        let travel = try store.createCategory(name: "Travel", color: .ocean)
        let entry = try store.createEntry(title: "Porto", day: day, minutesFromMidnight: 600, categoryID: travel.id)
        _ = try store.addPhoto(Self.photo, to: entry)
        store.trash(entry)
        clock.advance(days: 3)

        store.restoreFromTrash(entry)

        #expect(store.entries(on: day).map(\.id) == [entry.id])
        #expect(entry.dayKey == "2026-10-20" && entry.minutesFromMidnight == 600)
        #expect(entry.categoryID == travel.id)
        #expect(store.allPhotos().count == 1)
        #expect(store.trashCount == 0)
        #expect(entry.isDirty && entry.trashedAt == nil)
    }

    @Test("A completed task keeps its state through trash and restore")
    func completedTask() throws {
        let task = try store.createTask(title: "Post the letter", day: store.today)
        store.setCompleted(task, true)
        let completedAt = task.completedAt
        store.trash(task)
        #expect(store.trashedTasks().first?.isCompleted == true)
        store.restoreFromTrash(task)
        #expect(task.isCompleted && task.completedAt == completedAt)
        #expect(store.markers(for: store.today.monthKey, firstWeekday: 2)[store.today]?.doneTaskCount == 1)
    }

    @Test("Restoring a category re-links what it un-assigned, unless it was re-categorised since")
    func categoryRelink() throws {
        let travel = try store.createCategory(name: "Travel", color: .ocean)
        let work = try store.createCategory(name: "Work", color: .graphite)
        let entry = try store.createEntry(title: "Lisbon", day: store.today, categoryID: travel.id)
        let task = try store.createTask(title: "Pack", categoryID: travel.id)
        let moved = try store.createTask(title: "Book hotel", categoryID: travel.id)

        #expect(store.trash(travel) == 3)
        #expect(entry.categoryID == nil && task.categoryID == nil)
        try store.updateTask(moved, title: moved.title, notes: nil, day: nil, minutesFromMidnight: nil, categoryID: work.id)

        try store.restoreFromTrash(travel)

        #expect(store.categories().map(\.name) == ["Work", "Travel"])
        #expect(entry.categoryID == travel.id && task.categoryID == travel.id)
        #expect(moved.categoryID == work.id, "a newer choice wins")
        #expect(travel.unassignedIDs == nil)
    }

    @Test("A trashed category's items stay re-linkable even if one of them was trashed too")
    func categoryRelinkTrashedItem() throws {
        let travel = try store.createCategory(name: "Travel", color: .ocean)
        let entry = try store.createEntry(title: "Lisbon", day: store.today, categoryID: travel.id)
        store.trash(entry)
        store.trash(travel)
        try store.restoreFromTrash(travel)
        store.restoreFromTrash(entry)
        #expect(entry.categoryID == travel.id)
    }

    @Test("A restored category whose name is now taken gets a number")
    func categoryNameClash() throws {
        let travel = try store.createCategory(name: "Travel", color: .ocean)
        store.trash(travel)
        _ = try store.createCategory(name: "travel", color: .rose)
        try store.restoreFromTrash(travel)
        #expect(travel.name == "Travel 2")
    }

    @Test("Items are permanently deleted 30 days after they were trashed, not before")
    func purgeAt30Days() throws {
        let entry = try store.createEntry(title: "Old", day: store.today)
        _ = try store.addPhoto(Self.photo, to: entry)
        let task = try store.createTask(title: "Old task")
        let category = try store.createCategory(name: "Old", color: .sand)
        store.trash(entry)
        store.trash(task)
        store.trash(category)
        #expect(store.daysLeft(trashedAt: try #require(entry.trashedAt)) == 30)

        clock.advance(days: 29.9)
        #expect(store.purgeExpiredTrash() == 0)
        #expect(store.daysLeft(trashedAt: try #require(entry.trashedAt)) == 1)

        clock.advance(days: 0.2)
        #expect(store.purgeExpiredTrash() == 3)
        #expect(store.trashCount == 0)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Entry>()) == 0, "never-synced: deleted outright")
        #expect(try container.mainContext.fetchCount(FetchDescriptor<EntryPhoto>()) == 0, "photos go too")
        #expect(try container.mainContext.fetchCount(FetchDescriptor<TaskItem>()) == 0)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Folio.Category>()) == 0)
    }

    @Test("A synced item purges to a tombstone for sync, and stays gone")
    func purgeTombstone() throws {
        let entry = try store.createEntry(title: "Synced", day: store.today)
        entry.serverVersion = 4
        store.trash(entry)
        clock.advance(days: 31)
        store.purgeExpiredTrash()
        #expect(entry.isTombstone && entry.isDirty)
        #expect(store.trashedEntries().isEmpty && store.allEntries().isEmpty)
    }

    @Test("Moving the clock backwards never resurrects or stretches anything")
    func clockBackwards() throws {
        let task = try store.createTask(title: "Gone soon")
        store.trash(task)
        clock.advance(days: 31)
        let trashedAt = try #require(task.trashedAt)
        #expect(store.daysLeft(trashedAt: trashedAt) == 0)

        clock.advance(days: -40) // the user sets the clock back before the purge runs
        #expect(store.daysLeft(trashedAt: trashedAt) == 0, "the countdown doesn't grow back")
        #expect(store.purgeExpiredTrash() == 1, "still purged on time")
        #expect(store.allTasks().isEmpty && store.trashCount == 0)

        // The high-water mark survives a relaunch (a new store on the same defaults).
        let relaunched = DiaryStore(context: container.mainContext, calendar: TestCalendar.london, now: { clock.now },
                                    trashClockDefaults: defaults)
        #expect(relaunched.trashClockNow() > clock.now)
    }

    @Test("Delete now and Empty remove items permanently; Erase empties Recently Deleted")
    func deleteNowEmptyErase() throws {
        let a = try store.createTask(title: "A")
        let b = try store.createTask(title: "B")
        let entry = try store.createEntry(title: "C", day: store.today)
        store.trash(a)
        store.trash(b)
        store.trash(entry)
        store.deletePermanently(a)
        #expect(store.trashCount == 2)
        store.emptyTrash()
        #expect(store.trashCount == 0)

        let d = try store.createTask(title: "D")
        store.trash(d)
        store.eraseAll()
        #expect(store.trashCount == 0)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<TaskItem>()) == 0)
    }

    @Test("Export leaves Recently Deleted out by default, and includes it with the toggle")
    func export() async throws {
        let kept = try store.createEntry(title: "Kept", day: store.today)
        let gone = try store.createEntry(title: "Gone", day: store.today)
        _ = try store.addPhoto(Self.photo, to: gone)
        let goneTask = try store.createTask(title: "Gone task")
        store.trash(gone)
        store.trash(goneTask)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let plain = DataExporter(store: store)
        defer { plain.cleanUp() }
        let document = try decoder.decode(ExportDocument.self, from: Data(contentsOf: try await plain.export()[0]))
        #expect(document.entries.map(\.id) == [kept.id])
        #expect(document.tasks.isEmpty)

        let withTrash = DataExporter(store: store, includesTrash: true)
        defer { withTrash.cleanUp() }
        let full = try decoder.decode(ExportDocument.self, from: Data(contentsOf: try await withTrash.export()[0]))
        #expect(Set(full.entries.map(\.id)) == [kept.id, gone.id])
        #expect(full.entries.first { $0.id == gone.id }?.trashedAt != nil)
        #expect(full.entries.first { $0.id == gone.id }?.photos.count == 1)
        #expect(full.tasks.map(\.id) == [goneTask.id])
    }
}
