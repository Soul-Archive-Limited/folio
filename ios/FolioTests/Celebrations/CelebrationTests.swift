import Foundation
import SwiftData
import SwiftUI
import Testing
@testable import Folio

/// When gentle celebrations play (Batch N Part 4). Serialized: they share the
/// "celebrations" preference in standard defaults.
@MainActor
@Suite("Gentle celebrations", .serialized)
struct CelebrationTests {
    let store: DiaryStore
    let container: ModelContainer

    init() throws {
        UserDefaults.standard.removeObject(forKey: Celebration.settingKey)
        container = try FolioPersistence.makeContainer(inMemory: true)
        store = DiaryStore(context: container.mainContext, calendar: TestCalendar.london, now: { TestCalendar.date(2026, 11, 11, 9) })
    }

    private func composer(day: DayKey) -> ComposerModel {
        ComposerModel(day: day, categoryID: nil, writingFont: .newYork,
                      drafts: DraftStore(directory: .temporaryDirectory.appending(path: UUID().uuidString)))
    }

    @Test("Only the first page kept for a day counts — a second page or an edit doesn't")
    func firstPage() throws {
        let first = composer(day: store.today)
        first.title = "Morning"
        _ = try first.save(to: store, context: EnvironmentValues().fontResolutionContext)
        #expect(first.keptFirstPageForDay)

        let second = composer(day: store.today)
        second.title = "Evening"
        _ = try second.save(to: store, context: EnvironmentValues().fontResolutionContext)
        #expect(!second.keptFirstPageForDay)

        let entry = try #require(store.entries(on: store.today).first)
        let edit = ComposerModel(entry: entry, writingFont: .newYork, drafts: DraftStore(directory: .temporaryDirectory.appending(path: UUID().uuidString)))
        edit.title = "Morning swim"
        _ = try edit.save(to: store, context: EnvironmentValues().fontResolutionContext)
        #expect(!edit.keptFirstPageForDay)
    }

    @Test("Moving a page to an empty day counts as the first page there")
    func movedPage() throws {
        let entry = try store.createEntry(title: "Walk", day: store.today)
        _ = try store.createEntry(title: "Run", day: store.today)
        let edit = ComposerModel(entry: entry, writingFont: .newYork, drafts: DraftStore(directory: .temporaryDirectory.appending(path: UUID().uuidString)))
        edit.day = store.today.adding(days: -5)
        _ = try edit.save(to: store, context: EnvironmentValues().fontResolutionContext)
        #expect(edit.keptFirstPageForDay)
    }

    @Test("Ticking the last open task of a day fills its ring; not before, not for undated tasks")
    func tasksDone() throws {
        let a = try store.createTask(title: "Post letter", day: store.today)
        let b = try store.createTask(title: "Call Mum", day: store.today)
        let undated = try store.createTask(title: "Someday")
        store.setCompleted(a, true)
        #expect(store.celebration == nil)
        store.setCompleted(undated, true)
        #expect(store.celebration == nil)
        store.setCompleted(b, true)
        #expect(store.celebration?.kind == .tasksDone && store.celebration?.day == store.today)
    }

    @Test("Celebrations off, or changes arriving from sync: nothing plays")
    func offAndRemote() throws {
        UserDefaults.standard.set(false, forKey: Celebration.settingKey)
        defer { UserDefaults.standard.removeObject(forKey: Celebration.settingKey) }
        let task = try store.createTask(title: "Only one", day: store.today)
        store.setCompleted(task, true)
        #expect(store.celebration == nil)
        UserDefaults.standard.set(true, forKey: Celebration.settingKey)
        store.isApplyingRemote = true
        store.celebrate(.bloom, on: store.today)
        store.isApplyingRemote = false
        #expect(store.celebration == nil)
    }

    @Test("The quiet line names today, or the day kept")
    func line() {
        let today = DayKey(rawValue: "2026-11-11")!
        #expect(String(localized: Celebration.savedLine(for: today, today: today)) == "Today's page is kept.")
        // The date follows the device's region (CI runs en_US, the owner en_GB).
        let past = String(localized: Celebration.savedLine(for: DayKey(rawValue: "2026-11-04")!, today: today))
        #expect(past.hasPrefix("Kept on ") && past.contains("Wednesday") && past.contains("4") && past.contains("November"))
    }
}
