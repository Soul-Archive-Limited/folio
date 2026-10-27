import Foundation
import SwiftData
import Testing
@testable import Folio

@MainActor
@Suite("Diary store")
struct DiaryStoreTests {
    let container: ModelContainer
    let store: DiaryStore
    let clock: TestClock

    final class TestClock {
        var now: Date
        init(_ now: Date) { self.now = now }
    }

    init() throws {
        container = try FolioPersistence.makeContainer(inMemory: true)
        let clock = TestClock(TestCalendar.date(2026, 10, 14, 23, 30))
        self.clock = clock
        store = DiaryStore(context: container.mainContext, calendar: TestCalendar.london, now: { clock.now })
    }

    private func day(_ raw: String) throws -> DayKey { try #require(DayKey(rawValue: raw)) }

    @Test("Time-zone travel keeps an entry on its day (SPEC §5)")
    func timeZoneTravel() throws {
        let october14 = try day("2026-10-14")
        let entry = try store.createEntry(title: "Late dinner", body: "", day: october14, minutesFromMidnight: 23 * 60 + 30)

        // Fly to Tokyo, where it's already the 15th, then on to Los Angeles.
        for zone in ["Asia/Tokyo", "America/Los_Angeles", "Pacific/Kiritimati", "Pacific/Pago_Pago"] {
            store.calendar.timeZone = try #require(TimeZone(identifier: zone))
            #expect(store.entries(on: october14).map(\.id) == [entry.id], "zone \(zone)")
            #expect(entry.dayKey == "2026-10-14")
            #expect(store.markers(for: october14.monthKey, firstWeekday: 2)[october14]?.entryCount == 1)
        }
        // "Today" follows the phone, but the entry doesn't move.
        store.calendar.timeZone = try #require(TimeZone(identifier: "Asia/Tokyo"))
        #expect(store.today.rawValue == "2026-10-15")
        #expect(store.entries(on: store.today).isEmpty)
    }

    @Test("Completing a task never removes it from its day (SPEC §5)")
    func completingKeepsTask() throws {
        let today = store.today
        let task = try store.createTask(title: "Post the letter", day: today)
        store.setCompleted(task, true)
        #expect(store.tasks(on: today).map(\.id) == [task.id])
        #expect(task.isCompleted && task.completedAt == clock.now)
        let marker = try #require(store.markers(for: today.monthKey, firstWeekday: 2)[today])
        #expect(marker.doneTaskCount == 1 && marker.openTaskCount == 0 && marker.allTasksDone)

        store.setCompleted(task, false)
        #expect(task.completedAt == nil)
        #expect(store.tasks(on: today).count == 1)

        store.delete(task)
        #expect(store.tasks(on: today).isEmpty)
    }

    @Test("Deleting a category un-assigns its items and keeps them (SPEC §5)")
    func categoryDelete() throws {
        let travel = try store.createCategory(name: "Travel", color: .ocean)
        let entry = try store.createEntry(title: "Lisbon", day: store.today, categoryID: travel.id)
        let task = try store.createTask(title: "Pack", day: store.today, categoryID: travel.id)
        store.updateSettings { $0.defaultCategoryID = travel.id }

        #expect(store.usage(of: travel) == CategoryUsage(entries: 1, tasks: 1))
        store.delete(travel)

        #expect(store.categories().isEmpty)
        #expect(entry.categoryID == nil && task.categoryID == nil)
        #expect(entry.isDirty && task.isDirty)
        #expect(store.settings().defaultCategoryID == nil)
        #expect(store.entries(on: store.today).count == 1)
        #expect(store.tasks(on: store.today).count == 1)
    }

    @Test("Category names are 1–24 characters, unique ignoring case, max 30 categories")
    func categoryValidation() throws {
        _ = try store.createCategory(name: "Work", color: .graphite)
        #expect(throws: StoreError.duplicateCategoryName) { try store.createCategory(name: " work ", color: .rose) }
        #expect(throws: StoreError.categoryNameEmpty) { try store.createCategory(name: "   ", color: .rose) }
        #expect(throws: StoreError.categoryNameTooLong) {
            try store.createCategory(name: String(repeating: "x", count: 25), color: .rose)
        }
        for index in 1..<30 { _ = try store.createCategory(name: "C\(index)", color: .teal) }
        #expect(throws: StoreError.tooManyCategories) { try store.createCategory(name: "One more", color: .teal) }
    }

    @Test("Never-synced items are deleted outright; synced ones become tombstones")
    func tombstones() throws {
        let local = try store.createEntry(title: "Local", day: store.today)
        store.delete(local)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Entry>()) == 0)

        let synced = try store.createEntry(title: "Synced", day: store.today)
        synced.serverVersion = 7
        store.delete(synced)
        #expect(synced.isTombstone && synced.isDirty)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Entry>()) == 1)
        #expect(store.entries(on: store.today).isEmpty)
    }

    @Test("Month markers show photos, category dots and task rings")
    func markers() throws {
        let today = store.today
        let ideas = try store.createCategory(name: "Ideas", color: .violet)
        _ = try store.createEntry(title: "A", day: today, minutesFromMidnight: 60, categoryID: ideas.id)
        let withPhoto = try store.createEntry(title: "B", day: today, minutesFromMidnight: 600)
        let photo = try store.addPhoto(Self.fakePhoto, to: withPhoto)
        _ = try store.addPhoto(Self.fakePhoto, to: withPhoto)
        _ = try store.createTask(title: "Open", day: today)

        let marker = try #require(store.markers(for: today.monthKey, firstWeekday: 2)[today])
        #expect(marker.entryCount == 2)
        #expect(marker.thumbnailPhotoID == photo.id)
        #expect(marker.extraEntryCount == 1, "two entries, one shown as the photo")
        #expect(marker.dotCategoryIDs == [ideas.id])
        #expect(marker.openTaskCount == 1 && !marker.allTasksDone)
        #expect(marker.categoryIDs == [ideas.id])
    }

    @Test("Markers are recomputed after a write")
    func markerCache() throws {
        let today = store.today
        #expect(store.markers(for: today.monthKey, firstWeekday: 2)[today] == nil)
        _ = try store.createEntry(title: "New", day: today)
        #expect(store.markers(for: today.monthKey, firstWeekday: 2)[today]?.entryCount == 1)
    }

    @Test("Photos are limited to 10 per entry")
    func photoLimit() throws {
        let entry = try store.createEntry(title: "Album", day: store.today)
        for _ in 0..<10 { _ = try store.addPhoto(Self.fakePhoto, to: entry) }
        #expect(throws: StoreError.tooManyPhotos) { try store.addPhoto(Self.fakePhoto, to: entry) }
        #expect(entry.orderedPhotos.map(\.sortIndex) == Array(0..<10))
    }

    @Test("Greeting summary counts today's tasks, overdue tasks, this week's pages and on-this-day")
    func greetingSummary() throws {
        let today = store.today
        _ = try store.createTask(title: "Today 1", day: today)
        _ = try store.createTask(title: "Today 2", day: today)
        store.setCompleted(try store.createTask(title: "Done today", day: today), true)
        _ = try store.createTask(title: "Late", day: today.adding(days: -2))
        _ = try store.createTask(title: "Undated")
        _ = try store.createEntry(title: "This week", day: today.adding(days: -3))
        _ = try store.createEntry(title: "Too old", day: today.adding(days: -8))
        _ = try store.createEntry(title: "Last year", day: try day("2025-10-14"))
        _ = try store.createEntry(title: "Earlier", day: try day("2022-10-14"))

        let summary = store.greetingSummary()
        #expect(summary.tasksToday == 2)
        #expect(summary.tasksOverdue == 1)
        #expect(summary.pagesThisWeek == 1)
        #expect(summary.onThisDayYear == 2025)
    }

    @Test("Task titles are required and trimmed")
    func taskValidation() throws {
        #expect(throws: StoreError.taskTitleEmpty) { try store.createTask(title: "  ") }
        #expect(try store.createTask(title: "  Buy milk ").title == "Buy milk")
        #expect(throws: StoreError.notesTooLong) {
            try store.createTask(title: "x", notes: String(repeating: "n", count: 2001))
        }
    }

    @Test("Every write marks the record dirty and stamps updatedAt")
    func dirtyTracking() throws {
        let entry = try store.createEntry(title: "Draft", day: store.today)
        entry.isDirty = false
        clock.now = clock.now.addingTimeInterval(60)
        try store.updateEntry(entry, title: "Final", body: "Text", categoryID: nil)
        #expect(entry.isDirty && entry.updatedAt == clock.now)
    }

    @Test("Only one settings record exists")
    func settingsSingleton() throws {
        let first = store.settings()
        let second = store.settings()
        #expect(first.id == second.id)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<UserSettings>()) == 1)
    }

    static let fakePhoto = ProcessedPhoto(imageData: Data([1, 2, 3]), thumbnailData: Data([4, 5]),
                                          pixelWidth: 10, pixelHeight: 10, imageType: "public.jpeg")
}

@MainActor
@Suite("Erase data on this iPhone (SPEC §6.9)")
struct EraseTests {
    @Test("Erase removes every entry, photo, task, category, setting and draft")
    func eraseAll() throws {
        let container = try FolioPersistence.makeContainer(inMemory: true)
        let store = DiaryStore(context: container.mainContext)
        let category = try store.createCategory(name: "Work", color: .graphite)
        let entry = try store.createEntry(title: "A", day: store.today, categoryID: category.id)
        _ = try store.addPhoto(DiaryStoreTests.fakePhoto, to: entry)
        _ = try store.createTask(title: "T", day: store.today)
        _ = store.settings()
        store.drafts = DraftStore(directory: URL.temporaryDirectory.appending(path: "erase-\(UUID().uuidString)"))
        store.drafts.save(ComposerDraft(entryID: nil, dayKey: "2026-10-27", minutesFromMidnight: nil, title: "Half a thought",
                                        bodyMarkdown: "", categoryID: nil, savedAt: .now))
        #expect(store.drafts.load() != nil)
        store.eraseAll()
        #expect(store.drafts.load() == nil, "drafts are erased too")
        let context = container.mainContext
        #expect(try context.fetchCount(FetchDescriptor<Entry>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<EntryPhoto>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<TaskItem>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Folio.Category>()) == 0)
        #expect(store.isEmpty)
        #expect(store.entries(on: store.today).isEmpty && store.tasks(on: store.today).isEmpty)
    }
}
