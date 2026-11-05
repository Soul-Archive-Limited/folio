import Foundation
import os

/// Bringing in a paper diary page (Batch J): pages from the document camera or Photos → text
/// read on the device → a suggested date → a new entry with the scans as photos and the text
/// to edit.
@Observable
final class ScanModel {
    enum Phase: Equatable { case choosing, reading, review }

    private(set) var phase = Phase.choosing
    private(set) var images: [Data] = []
    var text = ""
    var day: DayKey
    private(set) var suggestedDay: DayKey?
    private(set) var isSaving = false
    @ObservationIgnored private let logger = Logger(subsystem: "com.devilsense.folio", category: "scan")

    init(today: DayKey) {
        day = today
    }

    /// The 10-photo limit per entry applies (SPEC §5).
    var droppedPages: Int { max(images.count - Entry.maximumPhotos, 0) }

    func read(_ pages: [Data], today: DayKey) async {
        guard !pages.isEmpty else { return }
        images = pages
        phase = .reading
        let result = await PageReader.read(pages)
        text = result.text
        suggestedDay = PageDateFinder.suggest(in: result.pages.first ?? "", today: today)
            ?? PageDateFinder.suggest(in: result.text, today: today)
        if let suggestedDay { day = suggestedDay }
        phase = .review
    }

    /// Creates the entry: the text as plain paragraphs, the scans as photos (GPS stripped and
    /// resized like any photo).
    func save(to store: DiaryStore) async -> Entry? {
        isSaving = true
        defer { isSaving = false }
        let lines = text.components(separatedBy: .newlines)
        let document = RichDocument(blocks: lines.map { RichDocument.Block(.paragraph, runs: $0.isEmpty ? [] : [RichDocument.Run($0)]) })
        guard let entry = try? store.createEntry(title: "", body: MarkdownCodec.markdown(from: document), day: day,
                                                 categoryID: store.settings().defaultCategoryID) else { return nil }
        let processor = PhotoProcessor()
        for image in images.prefix(Entry.maximumPhotos) {
            do {
                _ = try store.addPhoto(try await processor.process(image), to: entry)
            } catch {
                logger.error("Scan page couldn't be added: \(String(describing: type(of: error)), privacy: .public)")
            }
        }
        return entry
    }
}
