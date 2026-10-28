import FolioCrypto
import Foundation
import SwiftData
import Testing
@testable import Folio

/// Two devices' stores exchanging records the way the sync engine does (SPEC §10.3, §10.5):
/// payload → seal with the Data Key → server → open → apply. No network.
@MainActor
@Suite("Sync: payloads, last writer wins, tombstones")
struct SyncStoreTests {
    let deviceA: DiaryStore
    let deviceB: DiaryStore
    let containers: [ModelContainer]
    let key = DataKey.generate()
    let userID = UUID()
    var version: Int64 = 0

    init() throws {
        let a = try FolioPersistence.makeContainer(inMemory: true)
        let b = try FolioPersistence.makeContainer(inMemory: true)
        containers = [a, b]
        deviceA = DiaryStore(context: a.mainContext, calendar: TestCalendar.london, now: { TestCalendar.date(2026, 10, 27, 9) })
        deviceB = DiaryStore(context: b.mainContext, calendar: TestCalendar.london, now: { TestCalendar.date(2026, 10, 27, 10) })
    }

    static let photo = ProcessedPhoto(imageData: Data([1, 2]), thumbnailData: Data([3]), pixelWidth: 4, pixelHeight: 3,
                                      imageType: "public.heic", displayData: Data([4]))

    /// What the server would hold for `record` after accepting it.
    mutating func upload(_ record: DiaryStore.SyncModel, from store: DiaryStore) throws -> SyncWire.Remote {
        version += 1
        let type = Swift.type(of: record).recordType
        let stamp = record.updatedAt.millisecondsSince1970
        if record.isTombstone {
            return SyncWire.Remote(id: record.id, type: type.rawValue, version: version, ciphertext: "", nonce: "", clientUpdatedAt: stamp, deleted: true)
        }
        let sealed = try RecordCipher.seal(try store.payload(of: record), recordID: record.id, type: type, userID: userID, using: key)
        return SyncWire.Remote(id: record.id, type: type.rawValue, version: version, ciphertext: sealed.ciphertextAndTag.base64EncodedString(),
                               nonce: sealed.nonce.base64EncodedString(), clientUpdatedAt: stamp, deleted: false)
    }

    func download(_ remote: SyncWire.Remote, into store: DiaryStore) throws {
        let type = try #require(RecordType(rawValue: remote.type))
        var plain: Data?
        if !remote.deleted {
            let sealed = SealedRecord(nonce: try #require(Data(base64Encoded: remote.nonce)),
                                      ciphertextAndTag: try #require(Data(base64Encoded: remote.ciphertext)))
            plain = try RecordCipher.open(sealed, recordID: remote.id, type: type, userID: userID, using: key)
        }
        store.isApplyingRemote = true
        store.applyRemote(remote, type: type, plaintext: plain)
        store.linkOrphanPhotos()
        store.commit()
        store.isApplyingRemote = false
    }

    /// Pushes every dirty record of A to B and marks them synced on A.
    mutating func syncAll(from a: DiaryStore, to b: DiaryStore) throws {
        for record in a.dirtyRecords() {
            let remote = try upload(record, from: a)
            a.markSynced(record, version: remote.version, sentUpdatedAt: remote.clientUpdatedAt)
            try download(remote, into: b)
        }
        a.commit()
    }

    @Test("Every record type round-trips through encryption with all its fields")
    mutating func roundTrip() throws {
        let travel = try deviceA.createCategory(name: "Travel", color: .ocean)
        let entry = try deviceA.createEntry(title: "Swim", body: "The water was **cold**.", day: deviceA.today, minutesFromMidnight: 435, categoryID: travel.id)
        try deviceA.addPhoto(Self.photo, to: entry)
        let task = try deviceA.createTask(title: "Buy bread", notes: "Rye", day: deviceA.today, categoryID: travel.id)
        deviceA.setCompleted(task, true)
        deviceA.updateSettings { $0.displayName = "Sam"; $0.writingFont = WritingFont.sfPro.rawValue }

        try syncAll(from: deviceA, to: deviceB)

        let copy = try #require(deviceB.entry(id: entry.id))
        #expect(copy.title == "Swim" && copy.bodyMarkdown == entry.bodyMarkdown && copy.dayKey == entry.dayKey)
        #expect(copy.minutesFromMidnight == 435 && copy.categoryID == travel.id && !copy.isDirty)
        #expect(copy.orderedPhotos.count == 1)
        #expect(copy.orderedPhotos.first?.needsDownload == true)
        let taskCopy = try #require(deviceB.task(id: task.id))
        #expect(taskCopy.isCompleted && taskCopy.notes == "Rye" && taskCopy.completedAt == task.completedAt)
        #expect(deviceB.categories().map(\.name) == ["Travel"])
        #expect(deviceB.settings().displayName == "Sam")
        #expect(deviceB.settings().writingFont == WritingFont.sfPro.rawValue)
        #expect(!deviceA.hasDirtyRecords)
    }

    @Test("Last writer wins by updatedAt; a newer local edit stays and keeps the server version")
    mutating func lastWriterWins() throws {
        let entry = try deviceA.createEntry(title: "First", day: deviceA.today)
        try syncAll(from: deviceA, to: deviceB)
        let copy = try #require(deviceB.entry(id: entry.id))

        // B edits later than A's next edit: B's local edit is newer, so A's change doesn't overwrite it.
        try deviceA.updateEntry(entry, title: "From A", body: "", categoryID: nil)
        try deviceB.updateEntry(copy, title: "From B", body: "", categoryID: nil)
        let fromA = try upload(entry, from: deviceA)
        try download(fromA, into: deviceB)
        #expect(copy.title == "From B")
        #expect(copy.isDirty && copy.serverVersion == fromA.version)

        // An older remote edit loses; a newer one wins.
        let older = SyncWire.Remote(id: entry.id, type: "entry", version: 99, ciphertext: fromA.ciphertext, nonce: fromA.nonce,
                                    clientUpdatedAt: copy.updatedAt.millisecondsSince1970 + 1, deleted: false)
        try download(older, into: deviceB)
        #expect(copy.title == "From A" && !copy.isDirty)
    }

    @Test("Trash and restore travel inside the payload")
    mutating func trashSyncs() throws {
        let entry = try deviceA.createEntry(title: "Oops", day: deviceA.today)
        try syncAll(from: deviceA, to: deviceB)
        deviceA.trash(entry)
        try syncAll(from: deviceA, to: deviceB)
        #expect(deviceB.trashedEntries().map(\.id) == [entry.id])
        #expect(deviceB.entry(id: entry.id) == nil)

        deviceA.restoreFromTrash(entry)
        try syncAll(from: deviceA, to: deviceB)
        #expect(deviceB.trashedEntries().isEmpty)
        #expect(deviceB.entry(id: entry.id) != nil)
    }

    @Test("A purge is a tombstone: it deletes everywhere, even over a local edit, and is acknowledged away")
    mutating func tombstones() throws {
        let entry = try deviceA.createEntry(title: "Gone", day: deviceA.today)
        try syncAll(from: deviceA, to: deviceB)
        let copy = try #require(deviceB.entry(id: entry.id))
        try deviceB.updateEntry(copy, title: "Edited", body: "", categoryID: nil)

        deviceA.deletePermanently(entry)
        #expect(entry.isTombstone)
        try syncAll(from: deviceA, to: deviceB)
        #expect(deviceB.syncedRecord(id: entry.id, type: .entry) == nil)
        #expect(deviceA.syncedRecord(id: entry.id, type: .entry) == nil)
    }

    @Test("A record edited while its push was in flight stays dirty")
    mutating func editDuringPush() throws {
        let entry = try deviceA.createEntry(title: "Draft", day: deviceA.today)
        let sent = try upload(entry, from: deviceA)
        entry.updatedAt = entry.updatedAt.addingTimeInterval(1)
        deviceA.markSynced(entry, version: sent.version, sentUpdatedAt: sent.clientUpdatedAt)
        #expect(entry.isDirty && entry.serverVersion == sent.version)
    }

    @Test("A photo that arrives before its entry is linked when the entry comes")
    mutating func orphanPhoto() throws {
        let entry = try deviceA.createEntry(title: "Beach", day: deviceA.today)
        let photo = try deviceA.addPhoto(Self.photo, to: entry)
        let photoRemote = try upload(photo, from: deviceA)
        let entryRemote = try upload(entry, from: deviceA)
        try download(photoRemote, into: deviceB)
        #expect((deviceB.syncedRecord(id: photo.id, type: .entryPhoto) as? EntryPhoto)?.entry == nil)
        try download(entryRemote, into: deviceB)
        #expect(deviceB.entry(id: entry.id)?.photos.map(\.id) == [photo.id])
    }

    @Test("Joining an existing account: its settings win over this device's never-synced ones")
    mutating func accountSettingsWin() throws {
        deviceA.updateSettings { $0.displayName = "Sam" }
        try syncAll(from: deviceA, to: deviceA)  // marks A synced
        deviceB.updateSettings { $0.displayName = "New phone" }
        deviceB.letAccountSettingsWin()
        try download(try upload(deviceA.settings(), from: deviceA), into: deviceB)
        #expect(deviceB.settings().displayName == "Sam")
    }

    @Test("Detaching from an account makes everything unsynced again and drops tombstones and empty photos")
    mutating func detach() throws {
        let kept = try deviceA.createEntry(title: "Kept", day: deviceA.today)
        let gone = try deviceA.createEntry(title: "Gone", day: deviceA.today)
        try syncAll(from: deviceA, to: deviceB)
        deviceB.deletePermanently(try #require(deviceB.entry(id: gone.id)))
        let remotePhoto = EntryPhoto(id: UUID(), entryID: kept.id, sortIndex: 0, pixelWidth: 1, pixelHeight: 1, createdAt: .now, updatedAt: .now)
        deviceB.context.insert(remotePhoto)
        deviceB.commit()

        deviceB.detachFromAccount()
        let copy = try #require(deviceB.entry(id: kept.id))
        #expect(copy.serverVersion == nil && copy.isDirty)
        #expect(deviceB.syncedRecord(id: gone.id, type: .entry) == nil)
        #expect(deviceB.syncedRecord(id: remotePhoto.id, type: .entryPhoto) == nil)
    }
}
