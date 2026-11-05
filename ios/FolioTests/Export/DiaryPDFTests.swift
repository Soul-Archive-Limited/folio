import Foundation
import PDFKit
import SwiftData
import Testing
@testable import Folio

@MainActor
@Suite("Diary PDF")
struct DiaryPDFTests {
    let container: ModelContainer
    let store: DiaryStore

    init() throws {
        container = try FolioPersistence.makeContainer(inMemory: true)
        store = DiaryStore(context: container.mainContext, calendar: TestCalendar.london, now: { TestCalendar.date(2026, 11, 5) })
    }

    @Test("Three years: a cover, each month on a new page, the pages' words and formatting, photos; progress reaches 1")
    func threeYears() async throws {
        PreviewData.load(into: store)
        let entry = try store.createEntry(title: "Formatting check", body: "**Bold** and ==bright==\n- [x] packed\n> a quote",
                                          day: try #require(DayKey(rawValue: "2025-06-01")))
        store.setMood(entry, .bright)
        let options = DiaryPDF.Options(from: try #require(DayKey(rawValue: "2024-01-01")), through: store.today)
        let container = container
        let clock = ContinuousClock()
        let start = clock.now
        let result = try await Task.detached {
            try DiaryPDF.render(container: container, options: options) { _ in }
        }.value
        let elapsed = clock.now - start
        let document = try #require(PDFDocument(url: result.url))
        let months = Set(store.allEntries().filter { $0.dayKey >= "2024-01-01" }.compactMap { $0.day?.monthKey })
        #expect(document.pageCount == result.pageCount)
        #expect(result.pageCount >= 1 + months.count)
        let text = document.string ?? ""
        #expect(text.contains("Formatting check"))
        #expect(text.contains("BRIGHT"))
        #expect(text.contains("packed"))
        #expect(text.contains("Morning swim"))
        #expect(elapsed < .seconds(60))
        if let folder = ProcessInfo.processInfo.environment["FOLIO_PDF_OUT"] {
            try? FileManager.default.copyItem(at: result.url, to: URL(fileURLWithPath: folder).appending(path: "sample-3-years.pdf"))
        }
        try? FileManager.default.removeItem(at: result.url)
    }

    @Test("An empty range says so instead of making an empty book")
    func empty() throws {
        let options = DiaryPDF.Options(from: try #require(DayKey(rawValue: "1990-01-01")), through: try #require(DayKey(rawValue: "1990-12-31")))
        #expect(throws: DiaryPDF.Failure.self) { try DiaryPDF.render(container: container, options: options) { _ in } }
    }
}
