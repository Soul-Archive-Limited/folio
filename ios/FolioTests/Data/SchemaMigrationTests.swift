import Foundation
import SwiftData
import Testing
@testable import Folio

@MainActor
@Suite("Schema migration")
struct SchemaMigrationTests {
    @Test("A v1 store opens as v2; its photos get a display rendition from the backfill")
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

        let schema = Schema(versionedSchema: FolioSchemaV2.self)
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
}
