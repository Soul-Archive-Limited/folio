import Foundation
import SwiftData
import Testing
@testable import Folio

@MainActor
@Suite("Journal (SPEC §6.6)")
struct JournalModelTests {
    let container: ModelContainer
    let store: DiaryStore

    init() throws {
        container = try FolioPersistence.makeContainer(inMemory: true)
        store = DiaryStore(context: container.mainContext, calendar: TestCalendar.london,
                           now: { TestCalendar.date(2026, 10, 27, 9) })
    }

    static let photo = ProcessedPhoto(imageData: Data([1]), thumbnailData: Data([2]), pixelWidth: 4, pixelHeight: 3,
                                      imageType: "public.jpeg")

    @Test("Timeline groups entries into months, newest first")
    func monthSections() throws {
        _ = try store.createEntry(title: "Oct A", day: try #require(DayKey(rawValue: "2026-10-03")))
        _ = try store.createEntry(title: "Oct B", day: try #require(DayKey(rawValue: "2026-10-20")))
        _ = try store.createEntry(title: "Aug", day: try #require(DayKey(rawValue: "2026-08-01")))
        _ = try store.createEntry(title: "Old", day: try #require(DayKey(rawValue: "1999-12-31")))
        let sections = JournalModel().sections(store: store)
        #expect(sections.map(\.month) == [MonthKey(year: 2026, month: 10), MonthKey(year: 2026, month: 8), MonthKey(year: 1999, month: 12)])
        #expect(sections[0].entries.map(\.title) == ["Oct B", "Oct A"])
    }

    @Test("Sections refresh after a write and follow the category filter")
    func cacheAndFilter() throws {
        let model = JournalModel()
        let travel = try store.createCategory(name: "Travel", color: .ocean)
        _ = try store.createEntry(title: "Trip", day: store.today, categoryID: travel.id)
        #expect(model.sections(store: store).flatMap(\.entries).count == 1)
        _ = try store.createEntry(title: "Home", day: store.today)
        #expect(model.sections(store: store).flatMap(\.entries).count == 2, "cache invalidated by the write")
        model.filter = [travel.id]
        #expect(model.sections(store: store).flatMap(\.entries).map(\.title) == ["Trip"])
    }

    @Test("Photos view lists every photo, filtered by its entry's category")
    func photos() throws {
        let food = try store.createCategory(name: "Food", color: .sand)
        let lunch = try store.createEntry(title: "Lunch", day: store.today, categoryID: food.id)
        let walk = try store.createEntry(title: "Walk", day: store.today.adding(days: -1))
        _ = try store.addPhoto(Self.photo, to: lunch)
        _ = try store.addPhoto(Self.photo, to: walk)
        _ = try store.addPhoto(Self.photo, to: walk)
        let model = JournalModel()
        #expect(model.photos(store: store).count == 3)
        model.filter = [food.id]
        #expect(model.photos(store: store).map { $0.entry?.title } == ["Lunch"])
        store.delete(walk)
        model.filter = []
        #expect(model.photos(store: store).count == 1, "deleted entries' photos disappear")
    }

    @Test("Masonry spreads photos so the three columns stay balanced")
    func masonry() throws {
        // Two entries: an entry holds at most 10 photos.
        let entries = [try store.createEntry(title: "Album 1", day: store.today), try store.createEntry(title: "Album 2", day: store.today)]
        for index in 0..<12 {
            let tall = index.isMultiple(of: 3)
            _ = try store.addPhoto(ProcessedPhoto(imageData: Data([1]), thumbnailData: Data([2]), pixelWidth: tall ? 3 : 4,
                                                  pixelHeight: tall ? 4 : 3, imageType: "public.jpeg"), to: entries[index % 2])
        }
        let columns = JournalPhotoGrid.columns(for: entries.flatMap(\.orderedPhotos))
        #expect(columns.count == 3)
        #expect(columns.flatMap { $0 }.count == 12)
        let heights = columns.map { $0.reduce(0) { $0 + 1 / JournalPhotoGrid.aspect($1) } }
        #expect((heights.max() ?? 0) - (heights.min() ?? 0) < 1.4, "within about one photo of each other")
    }
}

@MainActor
@Suite("Categories manager (SPEC §6.10)")
struct CategoriesManagerTests {
    let container: ModelContainer
    let store: DiaryStore

    init() throws {
        container = try FolioPersistence.makeContainer(inMemory: true)
        store = DiaryStore(context: container.mainContext)
    }

    @Test("Reordering changes the order everywhere categories are listed")
    func reorder() throws {
        let a = try store.createCategory(name: "A", color: .ember)
        let b = try store.createCategory(name: "B", color: .ocean)
        let c = try store.createCategory(name: "C", color: .sage)
        store.reorderCategories([c, a, b])
        #expect(store.categories().map(\.name) == ["C", "A", "B"])
    }

    @Test("Editing keeps names unique and lets a category keep its own name")
    func edit() throws {
        let work = try store.createCategory(name: "Work", color: .graphite)
        _ = try store.createCategory(name: "Home", color: .rose)
        try store.updateCategory(work, name: "Work", color: .indigo, symbol: "briefcase")
        #expect(work.color == .indigo && work.symbol == "briefcase")
        #expect(throws: StoreError.duplicateCategoryName) {
            try store.updateCategory(work, name: "HOME", color: .indigo, symbol: nil)
        }
    }

    @Test("Every curated symbol is unique and there are 40")
    func symbols() {
        #expect(CategorySymbols.all.count == 40)
        #expect(Set(CategorySymbols.all).count == 40)
    }
}
