import Foundation
import SwiftData
import Testing
@testable import Folio

@MainActor
@Suite("Profile (SPEC §6.9)")
struct ProfileTests {
    let container: ModelContainer
    let store: DiaryStore

    init() throws {
        container = try FolioPersistence.makeContainer(inMemory: true)
        store = DiaryStore(context: container.mainContext, calendar: TestCalendar.london,
                           now: { TestCalendar.date(2026, 10, 27, 9) })
    }

    static let photo = ProcessedPhoto(imageData: Data([1, 2]), thumbnailData: Data([3]), pixelWidth: 4, pixelHeight: 3,
                                      imageType: "public.heic", displayData: Data([4]))

    @Test("Archive counts entries, photos, distinct days written on and finished tasks")
    func stats() throws {
        let day = try #require(DayKey(rawValue: "2026-10-01"))
        let first = try store.createEntry(title: "A", day: day)
        _ = try store.createEntry(title: "B", day: day)
        _ = try store.createEntry(title: "C", day: try #require(DayKey(rawValue: "1999-01-01")))
        _ = try store.addPhoto(Self.photo, to: first)
        let done = try store.createTask(title: "Done")
        store.setCompleted(done, true)
        _ = try store.createTask(title: "Open")

        let stats = store.profileStats()
        #expect(stats.entries == 3)
        #expect(stats.photos == 1)
        #expect(stats.daysWrittenOn == 2)
        #expect(stats.tasksDone == 1)
        #expect(stats.writingSince?.rawValue == "1999-01-01", "the earliest day written for, not when it was written")
    }

    @Test("An empty diary has no 'writing since'")
    func emptyStats() {
        #expect(store.profileStats() == ProfileStats())
    }

    @Test("Monogram uses up to two initials")
    func monogram() {
        #expect(Monogram(name: "Sam Rivera Jones").initialsForTesting == "SR")
        #expect(Monogram(name: "ana").initialsForTesting == "A")
        #expect(Monogram(name: "").initialsForTesting.isEmpty)
    }

    @Test("Export writes JSON with Markdown bodies and a zip holding every photo")
    func export() async throws {
        let category = try store.createCategory(name: "Travel", color: .ocean)
        let entry = try store.createEntry(title: "Lisbon", body: "**Tram 28**", day: try #require(DayKey(rawValue: "2025-05-04")),
                                          categoryID: category.id)
        _ = try store.addPhoto(Self.photo, to: entry)
        _ = try store.addPhoto(Self.photo, to: entry)
        _ = try store.createTask(title: "Post cards", day: store.today)

        let exporter = DataExporter(store: store)
        let urls = try await exporter.export()
        defer { exporter.cleanUp() }
        #expect(urls.map(\.lastPathComponent) == ["Folio Export.json", "Folio Photos.zip"])

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(ExportDocument.self, from: Data(contentsOf: urls[0]))
        #expect(document.entries.first?.bodyMarkdown == "**Tram 28**")
        #expect(document.entries.first?.photos.count == 2)
        #expect(document.categories.map(\.name) == ["Travel"])
        #expect(document.tasks.map(\.title) == ["Post cards"])

        let zip = try Data(contentsOf: urls[1])
        #expect(zip.prefix(2) == Data("PK".utf8), "a real zip archive")

        exporter.cleanUp()
        #expect(!FileManager.default.fileExists(atPath: urls[0].path(percentEncoded: false)), "clean-up removes the export")
    }
}

@Suite("Onboarding (SPEC §6.1)")
struct OnboardingTests {
    @Test("Pages run welcome × 3 → name → sync; Skip lands on the name step")
    func order() {
        #expect(OnboardingPage.allCases == [.kept, .anyDay, .privacy, .name, .sync])
        #expect(OnboardingPage.allCases.filter(\.isWelcome) == [.kept, .anyDay, .privacy])
        #expect(OnboardingPage.privacy.next == .name)
        #expect(OnboardingPage.sync.next == nil)
    }
}
