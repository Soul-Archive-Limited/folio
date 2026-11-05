import CryptoKit
import Foundation
import SwiftData
import Testing
@testable import Folio

@MainActor
// CI builds unsigned, so there is no App Group container there: these run on signed builds.
@Suite("Share into Folio", .serialized, .enabled(if: AppGroup.container != nil))
struct ShareInboxTests {
    let container: ModelContainer
    let store: DiaryStore

    init() throws {
        container = try FolioPersistence.makeContainer(inMemory: true)
        store = DiaryStore(context: container.mainContext, calendar: .current, now: { .now })
        ShareInbox.drain { _ in true }
    }

    @Test("Inbox files are sealed; the import makes an entry and empties the inbox")
    func importsNewPage() async throws {
        let today = store.today
        let photo = try #require(SampleImageRenderer.jpeg(seed: 3))
        try ShareInbox.add(ShareInbox.Item(dayKey: today.rawValue, appendsToDay: false, title: "From Safari",
                                           text: "A quote worth keeping", link: "https://example.com/a", photos: [photo]))
        let folder = try #require(AppGroup.folder("Inbox"))
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        let sealed = try Data(contentsOf: try #require(files.first))
        #expect(sealed.range(of: Data("quote".utf8)) == nil, "the inbox holds only ciphertext")

        #expect(await ShareInboxImporter.importPending(into: store) == 1)
        let entry = try #require(store.entries(on: today).first)
        #expect(entry.title == "From Safari")
        #expect(entry.bodyMarkdown.contains("A quote worth keeping") && entry.bodyMarkdown.contains("example.com"))
        #expect(entry.orderedPhotos.count == 1)
        #expect(await ShareInboxImporter.importPending(into: store) == 0)
    }

    @Test("Add to that day's page appends to its latest entry")
    func appends() async throws {
        let today = store.today
        let entry = try store.createEntry(title: "Day", body: "Morning.", day: today)
        try ShareInbox.add(ShareInbox.Item(dayKey: today.rawValue, appendsToDay: true, text: "Evening.", photos: []))
        #expect(await ShareInboxImporter.importPending(into: store) == 1)
        #expect(store.entries(on: today).count == 1)
        #expect(entry.bodyMarkdown.hasPrefix("Morning.") && entry.bodyMarkdown.hasSuffix("Evening."))
    }

    @Test("A file sealed with another key is dropped, not imported")
    func foreignFile() async throws {
        let folder = try #require(AppGroup.folder("Inbox"))
        let other = SymmetricKey(size: .bits256)
        let junk = try #require(try AES.GCM.seal(Data("{}".utf8), using: other).combined)
        try junk.write(to: folder.appending(path: "\(UUID().uuidString).sealed"))
        #expect(await ShareInboxImporter.importPending(into: store) == 0)
        #expect((try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))).isEmpty)
    }
}
