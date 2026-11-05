import os
import SwiftUI
import UIKit

/// Brings in what was shared to Folio from other apps (Batch J): opens the share extension's
/// sealed inbox, makes entries (or adds to that day's page), and keeps the extension's small
/// sealed context — categories, which recent days have a page — up to date.
@MainActor
enum ShareInboxImporter {
    private static let logger = Logger(subsystem: "com.devilsense.folio", category: "share")

    /// Returns how many shared items were added.
    @discardableResult
    static func importPending(into store: DiaryStore) async -> Int {
        guard UIApplication.shared.isProtectedDataAvailable else { return 0 }
        var waiting: [ShareInbox.Item] = []
        ShareInbox.drain { item in
            waiting.append(item)
            return true
        }
        var added = 0
        for item in waiting where await add(item, to: store) { added += 1 }
        return added
    }

    private static func add(_ item: ShareInbox.Item, to store: DiaryStore) async -> Bool {
        guard let day = DayKey(rawValue: item.dayKey) else { return false }
        var paragraphs = [item.text, item.link].compactMap { $0 }.flatMap { $0.components(separatedBy: .newlines) }
        if paragraphs.isEmpty && item.photos.isEmpty { return false }
        let entry: Entry
        if item.appendsToDay, let existing = store.entries(on: day).last {
            let current = MarkdownCodec.document(from: existing.bodyMarkdown)
            if !current.blocks.isEmpty { paragraphs.insert("", at: 0) }
            let added = RichDocument(blocks: paragraphs.map { RichDocument.Block(.paragraph, runs: $0.isEmpty ? [] : [RichDocument.Run($0)]) })
            let body = MarkdownCodec.markdown(from: RichDocument(blocks: current.blocks + added.blocks))
            try? store.updateEntry(existing, title: existing.title, body: body, categoryID: existing.categoryID)
            entry = existing
        } else {
            let document = RichDocument(blocks: paragraphs.map { RichDocument.Block(.paragraph, runs: $0.isEmpty ? [] : [RichDocument.Run($0)]) })
            let category = item.categoryID.flatMap { store.category(id: $0) }?.id
            guard let created = try? store.createEntry(title: String((item.title ?? "").prefix(Entry.titleLengths.upperBound)),
                                                       body: MarkdownCodec.markdown(from: document), day: day, categoryID: category) else { return false }
            entry = created
        }
        let processor = PhotoProcessor()
        for photo in item.photos.prefix(max(Entry.maximumPhotos - entry.orderedPhotos.count, 0)) {
            do {
                _ = try store.addPhoto(try await processor.process(photo), to: entry)
            } catch {
                logger.error("Shared photo couldn't be added: \(String(describing: type(of: error)), privacy: .public)")
            }
        }
        return true
    }

    /// Categories and recent days with pages, sealed for the extension.
    static func writeContext(store: DiaryStore) {
        guard UIApplication.shared.isProtectedDataAvailable else { return }
        let today = store.today
        let recent = (0..<30).map { today.adding(days: -$0) }.filter { !store.entries(on: $0).isEmpty }.map(\.rawValue)
        let categories = store.categories().map { category in
            ShareInbox.Context.Category(id: category.id, name: category.name, colorHex: "")
        }
        ShareInbox.writeContext(ShareInbox.Context(categories: categories, defaultCategoryID: store.settings().defaultCategoryID,
                                                   daysWithPages: recent))
    }
}
