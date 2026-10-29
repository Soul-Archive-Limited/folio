import FolioCrypto
import Foundation

/// Photos travel as three encrypted blobs in R2 — thumbnail, 1080 px display and full —
/// sealed with the Data Key, associated data `photoId|rendition|userId` (SPEC §10.3, §10.5).
/// One transfer at a time (SPEC allows two; one keeps the main actor's SwiftData objects
/// simple and is fast enough for photos of ≤ 600 KB); an upload sends all three renditions in
/// one request. Downloads fetch every thumbnail first.
extension SyncEngine {
    enum Rendition: String, CaseIterable {
        case thumb, display, full

        var recordType: RecordType {
            switch self {
            case .thumb: .thumbnailBlob
            case .display: .displayBlob
            case .full: .photoBlob
            }
        }

        func blobID(_ photoID: UUID) -> String { "\(photoID.uuidString.lowercased()).\(rawValue)" }
    }

    /// One photo per request — thumbnail, display and full together (Batch F, DECISIONS 190) —
    /// each marked uploaded as soon as it's in R2, so a rate limit part-way loses nothing sent.
    func uploadPendingBlobs(userID: UUID, key: DataKey) async throws(APIError) {
        let processor = PhotoProcessor()
        for photo in store.photosNeedingUpload() {
            var sealed: [Data] = []
            for rendition in Rendition.allCases {
                // Display and full go up as JPEG so every browser can show them (DECISIONS 193).
                let bytes: Data = switch rendition {
                case .thumb: photo.thumbData
                case .display: await processor.syncCopy(of: photo.displayOrFullData, quality: 0.72)
                case .full: await processor.syncCopy(of: photo.imageData, quality: 0.82)
                }
                guard let part = try? RecordCipher.seal(bytes, recordID: photo.id, type: rendition.recordType, userID: userID, using: key) else { break }
                sealed.append(part.combined)
            }
            guard sealed.count == 3 else { continue }
            try await account.api.uploadPhoto(photo.id, thumb: sealed[0], display: sealed[1], full: sealed[2])
            photo.blobUploaded = true
            store.isApplyingRemote = true
            store.commit()
            store.isApplyingRemote = false
            advanceProgress(by: 1)
        }
    }

    func downloadPendingBlobs(userID: UUID, key: DataKey) async throws(APIError) {
        let photos = store.photosNeedingDownload()
        guard !photos.isEmpty else { return }
        for rendition in Rendition.allCases {
            for chunk in photos.chunked(into: 8) {
                var results: [UUID: Data] = [:]
                for photo in chunk where missing(photo, rendition) {
                    if let data = try await download(photo.id, rendition, userID: userID, key: key) { results[photo.id] = data }
                }
                guard !results.isEmpty else { continue }
                for photo in chunk {
                    guard let data = results[photo.id] else { continue }
                    switch rendition {
                    case .thumb: photo.thumbData = data
                    case .display: photo.displayData = data
                    case .full: photo.imageData = data
                    }
                }
                store.isApplyingRemote = true
                store.commit()
                store.photoBytesRevision += 1
                store.isApplyingRemote = false
            }
        }
    }

    /// Deletes a purged photo's blobs (SPEC §10.5: the 30-day purge removes R2 objects too).
    func deleteBlobs(of photoID: UUID) async {
        for rendition in Rendition.allCases {
            let _: OKResponse? = try? await account.api.send("DELETE", "blobs/\(rendition.blobID(photoID))")
        }
    }

    private func missing(_ photo: EntryPhoto, _ rendition: Rendition) -> Bool {
        guard !failedDownloads.contains(rendition.blobID(photo.id)) else { return false }
        return switch rendition {
        case .thumb: photo.thumbData.isEmpty
        case .display: photo.displayData == nil
        case .full: photo.imageData.isEmpty
        }
    }

    private func download(_ photoID: UUID, _ rendition: Rendition, userID: UUID, key: DataKey) async throws(APIError) -> Data? {
        let id = rendition.blobID(photoID)
        do throws(APIError) {
            let body = try await account.api.downloadBlob(id)
            guard let sealed = try? SealedRecord(combined: body),
                  let plain = try? RecordCipher.open(sealed, recordID: photoID, type: rendition.recordType, userID: userID, using: key) else {
                failedDownloads.insert(id)
                return nil
            }
            return plain
        } catch .server(404, _) {
            failedDownloads.insert(id)
            return nil
        }
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}
