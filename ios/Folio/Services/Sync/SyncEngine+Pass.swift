import FolioCrypto
import Foundation

/// One sync pass: pull pages after the cursor, then push dirty records in batches
/// (SPEC §10.5). Records are sealed and opened with the Data Key here; the server only ever
/// sees ciphertext, ids, types, versions, times and the deleted flag.
extension SyncEngine {
    func pull(userID: UUID, key: DataKey) async throws(APIError) {
        var cursor = SyncState.cursor(for: userID)
        var hasMore = true
        while hasMore {
            let page: SyncWire.PullResult = try await account.api.send("GET", "sync/pull?since=\(cursor)&limit=500")
            store.isApplyingRemote = true
            for remote in page.changes { apply(remote, userID: userID, key: key) }
            store.linkOrphanPhotos()
            store.commit()
            store.isApplyingRemote = false
            cursor = page.cursor
            SyncState.setCursor(cursor, for: userID)
            hasMore = page.hasMore
        }
    }

    func push(userID: UUID, key: DataKey) async throws(APIError) {
        // Photo records wait until their encrypted bytes are in R2, so another device never
        // sees a photo it can't download.
        let records = store.dirtyRecords().filter { record in
            guard let photo = record as? EntryPhoto else { return true }
            return photo.isTombstone || photo.blobUploaded
        }
        guard !records.isEmpty else { return }
        let total = records.count
        if total > 50 { setProgress((0, total)) }
        var done = 0
        for batch in batches(of: records, userID: userID, key: key) {
            let result: SyncWire.PushResult = try await account.api.send("POST", "sync/push", json: SyncWire.Push(changes: batch.map(\.change)))
            store.isApplyingRemote = true
            let byID = Dictionary(batch.map { ($0.change.id, $0) }, uniquingKeysWith: { first, _ in first })
            for accepted in result.accepted {
                guard let item = byID[accepted.id] else { continue }
                if let photo = item.record as? EntryPhoto, photo.isTombstone { await deleteBlobs(of: photo.id) }
                store.markSynced(item.record, version: accepted.version, sentUpdatedAt: item.change.clientUpdatedAt)
            }
            // The server copy won (newer `updatedAt`, or deleted): take it.
            for conflict in result.conflicts { apply(conflict, userID: userID, key: key) }
            store.commit()
            store.isApplyingRemote = false
            done += batch.count
            if total > 50 { setProgress((done, total)) }
        }
    }

    private func apply(_ remote: SyncWire.Remote, userID: UUID, key: DataKey) {
        guard let type = RecordType(rawValue: remote.type) else { return }
        var plaintext: Data?
        if !remote.deleted, let nonce = Data(base64Encoded: remote.nonce), let sealed = Data(base64Encoded: remote.ciphertext) {
            plaintext = try? RecordCipher.open(SealedRecord(nonce: nonce, ciphertextAndTag: sealed),
                                               recordID: remote.id, type: type, userID: userID, using: key)
            if plaintext == nil { logger.error("A record didn't decrypt (wrong key or tampered); skipped") }
        }
        store.applyRemote(remote, type: type, plaintext: plaintext)
    }

    struct Outgoing {
        let record: DiaryStore.SyncModel
        let change: SyncWire.Change
    }

    /// Seals each record and groups them under the push limits (200 changes, ~700 KB).
    private func batches(of records: [DiaryStore.SyncModel], userID: UUID, key: DataKey) -> [[Outgoing]] {
        var batches: [[Outgoing]] = []
        var current: [Outgoing] = []
        var bytes = 0
        for record in records {
            guard let change = change(for: record, userID: userID, key: key) else { continue }
            if current.count == SyncWire.maxChangesPerPush || (bytes + change.approximateBytes > SyncWire.maxPushBytes && !current.isEmpty) {
                batches.append(current)
                current = []
                bytes = 0
            }
            current.append(Outgoing(record: record, change: change))
            bytes += change.approximateBytes
        }
        if !current.isEmpty { batches.append(current) }
        return batches
    }

    private func change(for record: DiaryStore.SyncModel, userID: UUID, key: DataKey) -> SyncWire.Change? {
        let type = Swift.type(of: record).recordType
        let stamp = record.updatedAt.millisecondsSince1970
        if record.isTombstone {
            return SyncWire.Change(id: record.id, type: type.rawValue, ciphertext: "", nonce: "", clientUpdatedAt: stamp,
                                   baseVersion: record.serverVersion, deleted: true)
        }
        guard let plaintext = try? store.payload(of: record),
              let sealed = try? RecordCipher.seal(plaintext, recordID: record.id, type: type, userID: userID, using: key) else { return nil }
        return SyncWire.Change(id: record.id, type: type.rawValue, ciphertext: sealed.ciphertextAndTag.base64EncodedString(),
                               nonce: sealed.nonce.base64EncodedString(), clientUpdatedAt: max(stamp, 0),
                               baseVersion: record.serverVersion, deleted: false)
    }
}
