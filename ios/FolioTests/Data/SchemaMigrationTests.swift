import Foundation
import SwiftData
import Testing
@testable import Folio

@MainActor
@Suite("Schema migration")
struct SchemaMigrationTests {
    @Test("A v1 store opens as the current schema; its photos get a display rendition from the backfill")
    func v1ToV2() async throws {
        let url = URL.temporaryDirectory.appending(path: "migration-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }
        let entryID = UUID()
        let jpeg = try #require(SampleImageRenderer.jpeg(seed: 3, width: 3000, height: 2000))

        do {
            let schema = Schema(versionedSchema: FolioSchemaV1.self)
            let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
            let entry = FolioSchemaV1.Entry(id: entryID, title: "Old", bodyMarkdown: "", dayKey: "2024-06-01", now: .now)
            let photo = FolioSchemaV1.EntryPhoto(id: UUID(), entryID: entryID, now: .now)
            photo.imageData = jpeg
            photo.entry = entry
            container.mainContext.insert(entry)
            container.mainContext.insert(photo)
            try container.mainContext.save()
        }

        let schema = Schema(versionedSchema: FolioSchemaV4.self)
        let container = try ModelContainer(for: schema, migrationPlan: FolioMigrationPlan.self,
                                           configurations: ModelConfiguration(schema: schema, url: url))
        let store = DiaryStore(context: container.mainContext, calendar: TestCalendar.london, now: { .now })
        let entry = try #require(store.entry(id: entryID))
        #expect(entry.title == "Old")
        #expect(entry.orderedPhotos.first?.displayData == nil)

        await store.backfillDisplayRenditions()
        let display = try #require(entry.orderedPhotos.first?.displayData)
        #expect(!display.isEmpty && display.count < jpeg.count)
    }

    @Test("A v2 store opens as v3 (Recently Deleted): nothing is trashed, everything stays")
    func v2ToV3() throws {
        let url = URL.temporaryDirectory.appending(path: "migration-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }
        let categoryID = UUID(), entryID = UUID(), taskID = UUID()

        do {
            let schema = Schema(versionedSchema: FolioSchemaV2.self)
            let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
            let context = container.mainContext
            context.insert(FolioSchemaV2.Category(id: categoryID, name: "Travel", colorKey: "ocean", sortIndex: 0, now: .now))
            context.insert(FolioSchemaV2.Entry(id: entryID, title: "Lisbon", bodyMarkdown: "", dayKey: "2025-05-04",
                                               categoryID: categoryID, now: .now))
            context.insert(FolioSchemaV2.TaskItem(id: taskID, title: "Pack", dayKey: nil, sortIndex: 0, now: .now))
            try context.save()
        }

        let schema = Schema(versionedSchema: FolioSchemaV4.self)
        let container = try ModelContainer(for: schema, migrationPlan: FolioMigrationPlan.self,
                                           configurations: ModelConfiguration(schema: schema, url: url))
        let store = DiaryStore(context: container.mainContext, calendar: TestCalendar.london, now: { .now })
        let entry = try #require(store.entry(id: entryID))
        #expect(entry.trashedAt == nil && entry.categoryID == categoryID)
        #expect(store.categories().first?.trashedAt == nil && store.categories().first?.unassignedIDs == nil)
        #expect(store.task(id: taskID)?.trashedAt == nil)
        #expect(store.trashCount == 0)
    }

    @Test("A v3 store opens as v4: tasks and settings keep everything, the new fields are empty")
    func v3ToV4() throws {
        let url = URL.temporaryDirectory.appending(path: "migration-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }
        let taskID = UUID()

        do {
            let schema = Schema(versionedSchema: FolioSchemaV3.self)
            let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
            let context = container.mainContext
            let task = FolioSchemaV3.TaskItem(title: "Call Mum", day: DayKey(rawValue: "2026-10-28"), minutesFromMidnight: 1080,
                                              sortIndex: 0, now: .now)
            task.id = taskID
            context.insert(task)
            let settings = FolioSchemaV3.UserSettings(now: .now)
            settings.displayName = "Sam"
            context.insert(settings)
            try context.save()
        }

        let schema = Schema(versionedSchema: FolioSchemaV4.self)
        let container = try ModelContainer(for: schema, migrationPlan: FolioMigrationPlan.self,
                                           configurations: ModelConfiguration(schema: schema, url: url))
        let store = DiaryStore(context: container.mainContext, calendar: TestCalendar.london, now: { .now })
        let task = try #require(store.task(id: taskID))
        #expect(task.title == "Call Mum" && task.minutesFromMidnight == 1080)
        #expect(task.remindAt == nil && task.repeatRule == nil && task.parentID == nil)
        #expect(store.settings().displayName == "Sam")
        #expect(store.settings().avatar == nil && store.settings().avatarPhoto == nil)
    }
}
