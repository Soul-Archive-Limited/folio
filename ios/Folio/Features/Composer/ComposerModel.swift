import PhotosUI
import SwiftUI

/// State and actions for writing or editing an entry (SPEC §6.4).
@Observable
final class ComposerModel {
    let entryID: UUID?
    var day: DayKey { didSet { if day != oldValue { markEdited() } } }
    var minutesFromMidnight: Int? { didSet { if minutesFromMidnight != oldValue { markEdited() } } }
    var title: String = "" { didSet { if title != oldValue { markEdited() } } }
    var body = AttributedString() { didSet { if body != oldValue { markEdited() } } }
    var selection = AttributedTextSelection()
    var categoryID: UUID? { didSet { if categoryID != oldValue { markEdited() } } }
    var photos: [ComposerPhoto] = [] { didSet { if photos != oldValue { markEdited() } } }
    private(set) var hasChanges = false
    private(set) var isProcessingPhotos = false
    var pendingDraft: ComposerDraft?

    let writingFont: WritingFont
    @ObservationIgnored private var removedPhotoIDs: Set<UUID> = []
    @ObservationIgnored private var autosave: Task<Void, Never>?
    @ObservationIgnored private var editsSinceDraft = false
    @ObservationIgnored private let drafts: DraftStore
    @ObservationIgnored private var isLoading = true

    static let autosaveInterval: Duration = .seconds(2)

    /// A new entry for `day`.
    init(day: DayKey, categoryID: UUID?, writingFont: WritingFont, drafts: DraftStore = DraftStore()) {
        entryID = nil
        self.day = day
        self.categoryID = categoryID
        self.writingFont = writingFont
        self.drafts = drafts
        if let draft = drafts.load(), draft.entryID == nil, !draft.isEmpty { pendingDraft = draft }
        isLoading = false
    }

    /// Editing an existing entry.
    init(entry: Entry, writingFont: WritingFont, drafts: DraftStore = DraftStore()) {
        entryID = entry.id
        day = entry.day ?? DayKey(date: .now, calendar: .current)
        minutesFromMidnight = entry.minutesFromMidnight
        title = entry.title
        body = RichTextBridge.attributedString(fromMarkdown: entry.bodyMarkdown, writingFont: writingFont)
        categoryID = entry.categoryID
        photos = entry.orderedPhotos.map { .stored($0.id) }
        self.writingFont = writingFont
        self.drafts = drafts
        if let draft = drafts.load(), draft.entryID == entry.id, !draft.isEmpty { pendingDraft = draft }
        isLoading = false
    }

    var isNew: Bool { entryID == nil }

    /// Save is enabled once there's something worth keeping.
    var hasContent: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !String(body.characters).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !photos.isEmpty
    }

    var remainingPhotoSlots: Int { max(Entry.maximumPhotos - photos.count, 0) }

    func isPastDay(today: DayKey) -> Bool { day < today }

    private func markEdited() {
        guard !isLoading else { return }
        hasChanges = true
        editsSinceDraft = true
    }

    // MARK: Drafts

    func startAutosave(context: Font.Context) {
        autosave?.cancel()
        autosave = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.autosaveInterval)
                self?.writeDraftIfNeeded(context: context)
            }
        }
    }

    func stopAutosave() {
        autosave?.cancel()
        autosave = nil
    }

    func writeDraftIfNeeded(context: Font.Context) {
        guard editsSinceDraft else { return }
        editsSinceDraft = false
        let draft = makeDraft(context: context)
        if draft.isEmpty { drafts.clear() } else { drafts.save(draft) }
    }

    func makeDraft(context: Font.Context) -> ComposerDraft {
        ComposerDraft(entryID: entryID, dayKey: day.rawValue, minutesFromMidnight: minutesFromMidnight, title: title,
                      bodyMarkdown: RichTextBridge.markdown(from: body, context: context, writingFont: writingFont),
                      categoryID: categoryID, savedAt: AppClock.now)
    }

    func restoreDraft() {
        guard let draft = pendingDraft else { return }
        if let draftDay = DayKey(rawValue: draft.dayKey) { day = draftDay }
        minutesFromMidnight = draft.minutesFromMidnight
        title = draft.title
        body = RichTextBridge.attributedString(fromMarkdown: draft.bodyMarkdown, writingFont: writingFont)
        categoryID = draft.categoryID
        pendingDraft = nil
    }

    func discardDraft() {
        drafts.clear()
        pendingDraft = nil
    }

    // MARK: Photos

    func addPhotos(from items: [PhotosPickerItem]) async {
        isProcessingPhotos = true
        defer { isProcessingPhotos = false }
        let processor = PhotoProcessor()
        for item in items.prefix(remainingPhotoSlots) {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let processed = try? await processor.process(data) else { continue }
            photos.append(.new(processed))
        }
    }

    func addPhoto(data: Data) async {
        guard remainingPhotoSlots > 0 else { return }
        isProcessingPhotos = true
        defer { isProcessingPhotos = false }
        if let processed = try? await PhotoProcessor().process(data) { photos.append(.new(processed)) }
    }

    func removePhoto(_ photo: ComposerPhoto) {
        photos.removeAll { $0.id == photo.id }
        if let stored = photo.storedPhotoID { removedPhotoIDs.insert(stored) }
    }

    func movePhoto(_ id: UUID, before target: UUID) {
        guard let from = photos.firstIndex(where: { $0.id == id }),
              let to = photos.firstIndex(where: { $0.id == target }), from != to else { return }
        let photo = photos.remove(at: from)
        photos.insert(photo, at: to)
    }

    // MARK: Save

    /// Saves to the store (local-first) and clears the draft.
    @discardableResult
    func save(to store: DiaryStore, context: Font.Context) throws(StoreError) -> Entry {
        let markdown = RichTextBridge.markdown(from: body, context: context, writingFont: writingFont)
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry: Entry
        if let entryID, let existing = store.entry(id: entryID) {
            try store.updateEntry(existing, title: cleanTitle, body: markdown, categoryID: categoryID)
            if existing.day != day || existing.minutesFromMidnight != minutesFromMidnight {
                store.move(existing, to: day, minutesFromMidnight: minutesFromMidnight)
            }
            for photo in existing.orderedPhotos where removedPhotoIDs.contains(photo.id) { store.delete(photo) }
            entry = existing
        } else {
            entry = try store.createEntry(title: cleanTitle, body: markdown, day: day,
                                          minutesFromMidnight: minutesFromMidnight, categoryID: categoryID)
        }
        var order: [UUID] = []
        for photo in photos {
            if let stored = photo.storedPhotoID {
                order.append(stored)
            } else if let processed = photo.processed {
                order.append(try store.addPhoto(processed, to: entry).id)
            }
        }
        store.setPhotoOrder(entry, ids: order)
        stopAutosave()
        drafts.clear()
        hasChanges = false
        return entry
    }

    func discard() {
        stopAutosave()
        drafts.clear()
    }
}
