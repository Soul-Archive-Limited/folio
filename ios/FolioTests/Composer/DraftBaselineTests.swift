import Foundation
import SwiftData
import SwiftUI
import Testing
@testable import Folio

/// Batch E fix 8: "Continue your draft?" only for real unsaved changes.
@MainActor
@Suite("Drafts compare with the saved entry")
struct DraftBaselineTests {
    let container: ModelContainer
    let store: DiaryStore
    let drafts: DraftStore
    let context = EnvironmentValues().fontResolutionContext

    init() throws {
        container = try FolioPersistence.makeContainer(inMemory: true)
        store = DiaryStore(context: container.mainContext, calendar: TestCalendar.london,
                           now: { TestCalendar.date(2026, 10, 27, 9) })
        drafts = DraftStore(directory: URL.temporaryDirectory.appending(path: "drafts-\(UUID().uuidString)"))
    }

    private func savedEntry() throws -> Entry {
        try store.createEntry(title: "Train to Edinburgh", body: "Four hours of *fields*.", day: store.today)
    }

    @Test("Reopening a saved entry after editing and saving doesn't ask about a draft")
    func reopenAfterSave() throws {
        let entry = try savedEntry()
        let editor = ComposerModel(entry: entry, writingFont: .newYork, drafts: drafts)
        editor.startAutosave(context: context)
        editor.title = "Train to Edinburgh!"
        try editor.save(to: store, context: context)
        // The sheet's onDisappear runs after the save; it must not write the last edits back.
        editor.writeDraftIfNeeded(context: context)
        #expect(!editor.hasStoredDraft)
        let reopened = ComposerModel(entry: entry, writingFont: .newYork, drafts: drafts)
        #expect(reopened.pendingDraft == nil)
    }

    @Test("Opening a saved entry without changing it writes no draft")
    func noChangesNoDraft() throws {
        let entry = try savedEntry()
        let editor = ComposerModel(entry: entry, writingFont: .newYork, drafts: drafts)
        editor.startAutosave(context: context)
        // The editor may rewrite the same text (e.g. normalised attributes): still no change.
        editor.body = RichTextBridge.attributedString(fromMarkdown: entry.bodyMarkdown, writingFont: .newYork)
        editor.writeDraftIfNeeded(context: context)
        #expect(!editor.hasStoredDraft)
    }

    @Test("Typing then undoing back to the saved text removes the draft")
    func backToSavedClearsDraft() throws {
        let entry = try savedEntry()
        let editor = ComposerModel(entry: entry, writingFont: .newYork, drafts: drafts)
        editor.startAutosave(context: context)
        editor.title = "Train to Glasgow"
        editor.writeDraftIfNeeded(context: context)
        #expect(editor.hasStoredDraft)
        editor.title = "Train to Edinburgh"
        editor.writeDraftIfNeeded(context: context)
        #expect(!editor.hasStoredDraft)
    }

    @Test("A real unsaved change is offered again on reopen")
    func realChangeIsOffered() throws {
        let entry = try savedEntry()
        let editor = ComposerModel(entry: entry, writingFont: .newYork, drafts: drafts)
        editor.startAutosave(context: context)
        editor.title = "Train to Glasgow"
        editor.writeDraftIfNeeded(context: context)
        editor.stopAutosave()
        let reopened = ComposerModel(entry: entry, writingFont: .newYork, drafts: drafts)
        #expect(reopened.pendingDraft?.title == "Train to Glasgow")
    }

    @Test("A leftover draft identical to the saved entry is dropped without asking")
    func staleDraftDropped() throws {
        let entry = try savedEntry()
        drafts.save(ComposerDraft(entryID: entry.id, dayKey: entry.dayKey, minutesFromMidnight: nil,
                                  title: "Train to Edinburgh", bodyMarkdown: "Four hours of *fields*.\n",
                                  categoryID: nil, savedAt: .now))
        let reopened = ComposerModel(entry: entry, writingFont: .newYork, drafts: drafts)
        #expect(reopened.pendingDraft == nil)
        #expect(!reopened.hasStoredDraft)
    }

    @Test("Discarding clears the draft and writes no more")
    func discardClears() throws {
        let model = ComposerModel(day: store.today, categoryID: nil, writingFont: .newYork, drafts: drafts)
        model.startAutosave(context: context)
        model.title = "Half a thought"
        model.writeDraftIfNeeded(context: context)
        #expect(model.hasStoredDraft)
        model.title = "Half a thought, more"
        model.discard()
        model.writeDraftIfNeeded(context: context)
        #expect(!model.hasStoredDraft)
        #expect(ComposerModel(day: store.today, categoryID: nil, writingFont: .newYork, drafts: drafts).pendingDraft == nil)
    }

    @Test("Saving a new entry leaves no draft for the next new entry")
    func saveNewClears() throws {
        let model = ComposerModel(day: store.today, categoryID: nil, writingFont: .newYork, drafts: drafts)
        model.startAutosave(context: context)
        model.title = "Fresh page"
        model.writeDraftIfNeeded(context: context)
        model.title = "Fresh page!"
        try model.save(to: store, context: context)
        model.writeDraftIfNeeded(context: context)
        #expect(ComposerModel(day: store.today, categoryID: nil, writingFont: .newYork, drafts: drafts).pendingDraft == nil)
    }
}
