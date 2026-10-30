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
    /// What's already saved: the entry as stored, or nothing for a new entry. A draft is only
    /// kept while the writing differs from it (owner's iPhone test, Batch E).
    @ObservationIgnored private var baseline: ComposerDraft
    /// The saved entry as the editor writes it back (Markdown round trip), captured before the
    /// first edit, so normalised formatting never looks like an unsaved change.
    @ObservationIgnored private var editorBaseline: ComposerDraft?
    /// Set once the entry is saved or discarded; nothing is written as a draft after that.
    @ObservationIgnored private var isFinished = false

    static let autosaveInterval: Duration = .seconds(2)

    /// A new entry for `day`.
    init(day: DayKey, categoryID: UUID?, writingFont: WritingFont, drafts: DraftStore = DraftStore()) {
        entryID = nil
        self.day = day
        self.categoryID = categoryID
        self.writingFont = writingFont
        self.drafts = drafts
        baseline = ComposerDraft(entryID: nil, dayKey: day.rawValue, minutesFromMidnight: nil, title: "", bodyMarkdown: "",
                                 categoryID: categoryID, savedAt: .distantPast)
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
        baseline = ComposerDraft(entryID: entry.id, dayKey: entry.dayKey, minutesFromMidnight: entry.minutesFromMidnight,
                                 title: entry.title, bodyMarkdown: entry.bodyMarkdown, categoryID: entry.categoryID,
                                 photos: entry.orderedPhotos.map { DraftPhoto(id: $0.id, storedPhotoID: $0.id) },
                                 savedAt: .distantPast)
        if let draft = drafts.load(), draft.entryID == entry.id, !draft.isEmpty {
            // A leftover draft that only repeats what's saved isn't unsaved work: drop it quietly.
            if draft.hasSameContent(as: baseline) { drafts.clear() } else { pendingDraft = draft }
        }
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
        if !hasChanges, pendingDraft == nil, editorBaseline == nil { editorBaseline = makeDraft(context: context) }
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

    /// Keeps a draft only while there are unsaved changes compared with the saved entry; when
    /// the writing matches it again (or is empty), the draft is removed.
    func writeDraftIfNeeded(context: Font.Context) {
        guard editsSinceDraft, !isFinished else { return }
        editsSinceDraft = false
        let draft = makeDraft(context: context)
        if draft.isEmpty || matchesSaved(draft) {
            drafts.clear()
        } else {
            let newPhotos = photos.reduce(into: [UUID: ProcessedPhoto]()) { $0[$1.id] = $1.processed }
            drafts.save(draft, newPhotos: newPhotos)
        }
    }

    private func matchesSaved(_ draft: ComposerDraft) -> Bool {
        draft.hasSameContent(as: baseline) || editorBaseline.map(draft.hasSameContent(as:)) == true
    }

    func makeDraft(context: Font.Context) -> ComposerDraft {
        ComposerDraft(entryID: entryID, dayKey: day.rawValue, minutesFromMidnight: minutesFromMidnight, title: title,
                      bodyMarkdown: RichTextBridge.markdown(from: body, context: context, writingFont: writingFont),
                      categoryID: categoryID,
                      photos: photos.map { photo in
                          DraftPhoto(id: photo.id, storedPhotoID: photo.storedPhotoID,
                                     pixelWidth: photo.processed?.pixelWidth ?? 0, pixelHeight: photo.processed?.pixelHeight ?? 0,
                                     imageType: photo.processed?.imageType ?? "public.heic")
                      },
                      savedAt: AppClock.now)
    }

    func restoreDraft() {
        guard let draft = pendingDraft else { return }
        if let draftDay = DayKey(rawValue: draft.dayKey) { day = draftDay }
        minutesFromMidnight = draft.minutesFromMidnight
        title = draft.title
        body = RichTextBridge.attributedString(fromMarkdown: draft.bodyMarkdown, writingFont: writingFont)
        categoryID = draft.categoryID
        let original = Set(photos.compactMap(\.storedPhotoID))
        photos = draft.photos.compactMap { kept in
            if let stored = kept.storedPhotoID { return original.contains(stored) ? .stored(stored) : nil }
            return drafts.loadPhoto(kept).map { ComposerPhoto(id: kept.id, storedPhotoID: nil, processed: $0) }
        }
        removedPhotoIDs = original.subtracting(photos.compactMap(\.storedPhotoID))
        pendingDraft = nil
    }

    func discardDraft() {
        drafts.clear()
        pendingDraft = nil
    }

    /// Whether a draft is on disk for this composer (tests).
    var hasStoredDraft: Bool { drafts.load() != nil }

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

    // MARK: Dictation

    /// Set when the body editor has had focus, so dictation knows the cursor is meaningful.
    @ObservationIgnored var hasPlacedCursor = false

    /// Inserts a committed dictation phrase at the cursor (SPEC §6.11), spaced from the text
    /// before it and in the same font. Without a cursor it goes at the end.
    func insertDictation(_ phrase: String) {
        if !hasPlacedCursor {
            selection = AttributedTextSelection(insertionPoint: body.endIndex)
            hasPlacedCursor = true
        }
        let point: AttributedString.Index = switch selection.indices(in: body) {
        case .insertionPoint(let index): index
        case .ranges(let ranges): ranges.ranges.first?.lowerBound ?? body.endIndex
        }
        let previous = point > body.startIndex ? body.characters[body.characters.index(before: point)] : nil
        let text = DictationRules.insertion(phrase, after: previous)
        guard !text.isEmpty else { return }
        var styled = AttributedString(text)
        if point > body.startIndex {
            let before = body.characters.index(before: point)
            styled.mergeAttributes(body[before..<point].runs.first?.attributes ?? AttributeContainer())
        } else {
            styled.font = RichTextBridge.baseFont(writingFont)
        }
        body.replaceSelection(&selection, with: styled)
    }

    /// Swaps the most recent copy of `original` in the text for `replacement` (the dictation
    /// tidy-up), keeping that run's style. Returns false when it's no longer there.
    @discardableResult
    func replaceLast(_ original: String, with replacement: String) -> Bool {
        let characters = String(body.characters)
        guard let range = characters.range(of: original, options: .backwards) else { return false }
        let start = body.characters.index(body.startIndex, offsetBy: characters.distance(from: characters.startIndex, to: range.lowerBound))
        let end = body.characters.index(start, offsetBy: original.count)
        var styled = AttributedString(replacement)
        styled.mergeAttributes(body[start..<end].runs.first?.attributes ?? AttributeContainer())
        body.replaceSubrange(start..<end, with: styled)
        return true
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
        finish()
        return entry
    }

    func discard() {
        finish()
    }

    /// Saved or discarded: stop autosave, remove the draft, and write no more drafts — the
    /// sheet's `onDisappear` would otherwise store the last few seconds of edits again.
    private func finish() {
        stopAutosave()
        drafts.clear()
        isFinished = true
        editsSinceDraft = false
        hasChanges = false
    }
}
