import Foundation
import SwiftData
import Testing
@testable import Folio

/// SPEC §15.1: 10,000 entries and 5,000 photos must stay smooth. A month's markers are
/// computed on the main actor while paging, so they need to be well inside one frame budget
/// for cached reads and a few frames when a month is computed the first time.
@MainActor
@Suite("Calendar performance with 10,000 entries", .serialized)
struct CalendarPerformanceTests {
    @Test("Month markers stay fast with 10,000 entries and 5,000 photos")
    func markersAtScale() throws {
        let container = try FolioPersistence.makeContainer(inMemory: true)
        let store = DiaryStore(context: container.mainContext)
        PreviewData.loadStressData(into: store)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Entry>()) == 10_000)

        let month = store.today.monthKey
        let clock = ContinuousClock()
        let cold = clock.measure { _ = store.markers(for: month, firstWeekday: 2) }
        let warm = clock.measure { _ = store.markers(for: month, firstWeekday: 2) }
        let neighbours = clock.measure {
            for offset in 1...6 { _ = store.markers(for: month.adding(months: -offset), firstWeekday: 2) }
        }
        #expect(cold < .milliseconds(120), "cold \(cold)")
        #expect(warm < .milliseconds(2), "warm \(warm)")
        #expect(neighbours < .milliseconds(600), "6 months \(neighbours)")
        #expect(store.markers(for: month, firstWeekday: 2).values.contains { $0.thumbnailPhotoID != nil })
    }
}
