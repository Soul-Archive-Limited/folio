import Foundation
import SwiftData
import SwiftUI
import Testing
@testable import Folio

@MainActor
@Suite("Composer (SPEC §6.4)")
struct ComposerModelTests {
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

    static let photo = ProcessedPhoto(imageData: Data([1]), thumbnailData: Data([2]), pixelWidth: 4, pixelHeight: 3,
                                      imageType: "public.jpeg")

    @Test("Save is only enabled once there's content")
    func hasContent() {
        let model = ComposerModel(day: store.today, categoryID: nil, writingFont: .newYork, drafts: drafts)
        #expect(!model.hasContent && !model.hasChanges)
        model.body = AttributedString("   ")
        #expect(!model.hasContent && model.hasChanges)
        model.title = "Hello"
        #expect(model.hasContent)
    }

    @Test("Saving a new entry stores title, Markdown body, day, category and photos in order")
    func saveNew() throws {
        let model = ComposerModel(day: try #require(DayKey(rawValue: "1931-05-04")), categoryID: nil, writingFont: .newYork, drafts: drafts)
        model.title = "  Grandma's wedding "
        model.body = RichTextBridge.attributedString(fromMarkdown: "They danced **all** night.")
        model.photos = [.new(Self.photo), .new(Self.photo)]
        let entry = try model.save(to: store, context: context)
        #expect(entry.title == "Grandma's wedding")
        #expect(entry.bodyMarkdown == "They danced **all** night.")
        #expect(entry.dayKey == "1931-05-04")
        #expect(entry.orderedPhotos.count == 2)
        #expect(!model.hasChanges)
    }

    @Test("Editing moves the day, removes and reorders photos")
    func edit() throws {
        let entry = try store.createEntry(title: "Trip", day: store.today)
        let first = try store.addPhoto(Self.photo, to: entry)
        let second = try store.addPhoto(Self.photo, to: entry)
        let third = try store.addPhoto(Self.photo, to: entry)
        let model = ComposerModel(entry: entry, writingFont: .newYork, drafts: drafts)
        model.day = store.today.adding(days: -3)
        model.removePhoto(model.photos[0])
        model.movePhoto(third.id, before: second.id)
        try model.save(to: store, context: context)
        #expect(entry.dayKey == store.today.adding(days: -3).rawValue)
        #expect(entry.orderedPhotos.map(\.id) == [third.id, second.id])
        #expect(store.photo(id: first.id) == nil)
    }

    @Test("Drafts autosave and come back as 'Continue your draft?'")
    func draftRoundTrip() throws {
        let model = ComposerModel(day: store.today, categoryID: nil, writingFont: .newYork, drafts: drafts)
        model.title = "Half-written"
        model.body = RichTextBridge.attributedString(fromMarkdown: "- [ ] remember this")
        model.writeDraftIfNeeded(context: context)

        let reopened = ComposerModel(day: store.today, categoryID: nil, writingFont: .newYork, drafts: drafts)
        let pending = try #require(reopened.pendingDraft)
        #expect(pending.title == "Half-written")
        reopened.restoreDraft()
        #expect(reopened.title == "Half-written")
        #expect(RichTextBridge.markdown(from: reopened.body, context: context) == "- [ ] remember this")

        try reopened.save(to: store, context: context)
        #expect(drafts.load() == nil, "saving clears the draft")
    }

    @Test("Discarding clears the draft")
    func discard() {
        let model = ComposerModel(day: store.today, categoryID: nil, writingFont: .newYork, drafts: drafts)
        model.title = "Never mind"
        model.writeDraftIfNeeded(context: context)
        model.discard()
        #expect(drafts.load() == nil)
    }

    @Test("Photos are capped at 10")
    func photoCap() {
        let model = ComposerModel(day: store.today, categoryID: nil, writingFont: .newYork, drafts: drafts)
        model.photos = (0..<10).map { _ in ComposerPhoto.new(Self.photo) }
        #expect(model.remainingPhotoSlots == 0)
    }

    @Test("Past days use the past-date placeholder")
    func pastDay() throws {
        let model = ComposerModel(day: try #require(DayKey(rawValue: "1900-01-01")), categoryID: nil, writingFont: .newYork, drafts: drafts)
        #expect(model.isPastDay(today: store.today))
    }

    @Test("Delete with Undo restores the entry and its photos; duplicate copies it")
    func undoAndDuplicate() throws {
        let entry = try store.createEntry(title: "Keep me", body: "Text", day: store.today)
        _ = try store.addPhoto(Self.photo, to: entry)
        let snapshot = try #require(store.snapshot(of: entry))
        store.delete(entry)
        #expect(store.entries(on: store.today).isEmpty)
        let restored = try #require(store.restore(snapshot))
        #expect(restored.title == "Keep me" && restored.orderedPhotos.count == 1)
        let copy = try #require(store.duplicate(restored))
        #expect(copy.id != restored.id && copy.title == "Keep me")
        #expect(store.entries(on: store.today).count == 2)
    }

    @Test("Same day in other years finds other years only")
    func otherYears() throws {
        let today = try store.createEntry(title: "Now", day: store.today)
        _ = try store.createEntry(title: "Last year", day: store.today.adding(days: -365))
        _ = try store.createEntry(title: "Yesterday", day: store.today.adding(days: -1))
        let others = store.entriesOnSameDay(as: store.today, excluding: today.id)
        #expect(others.map(\.title) == ["Last year"])
    }
}
