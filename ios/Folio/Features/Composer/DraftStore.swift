import Foundation
import os

/// One draft on disk, inside the protected store directory (Application Support/Folio) and
/// written with `.completeFileProtection`: a draft is diary text too (SPEC §13.9). New
/// photos are kept beside it as files (full, display and thumbnail). The folder is excluded
/// from backup and removed when the draft is saved or discarded.
nonisolated struct DraftStore: Sendable {
    var directory: URL = FolioPersistence.storeDirectory.appending(path: "Drafts", directoryHint: .isDirectory)

    private var url: URL { directory.appending(path: "composer.json") }
    private var photoDirectory: URL { directory.appending(path: "Photos", directoryHint: .isDirectory) }
    private static let logger = Logger(subsystem: "com.devilsense.folio", category: "drafts")

    private enum Rendition: String, CaseIterable { case full, display, thumb }

    func load() -> ComposerDraft? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ComposerDraft.self, from: data)
    }

    /// Writes the draft and any new photo files not on disk yet, and removes files for
    /// photos that have left the draft.
    func save(_ draft: ComposerDraft, newPhotos: [UUID: ProcessedPhoto] = [:]) {
        do {
            try prepareDirectories()
            for (id, photo) in newPhotos where !FileManager.default.fileExists(atPath: file(id, .full).path(percentEncoded: false)) {
                try photo.imageData.write(to: file(id, .full), options: [.atomic, .completeFileProtection])
                try photo.displayData.write(to: file(id, .display), options: [.atomic, .completeFileProtection])
                try photo.thumbnailData.write(to: file(id, .thumb), options: [.atomic, .completeFileProtection])
            }
            removeFiles(except: Set(draft.photos.filter { $0.storedPhotoID == nil }.map(\.id)))
            try JSONEncoder().encode(draft).write(to: url, options: [.atomic, .completeFileProtection])
        } catch {
            Self.logger.error("Draft save failed: \(String(describing: type(of: error)), privacy: .public)")
        }
    }

    /// A new photo kept by the draft, or nil if its files are gone.
    func loadPhoto(_ photo: DraftPhoto) -> ProcessedPhoto? {
        guard photo.storedPhotoID == nil,
              let full = try? Data(contentsOf: file(photo.id, .full)),
              let thumb = try? Data(contentsOf: file(photo.id, .thumb)) else { return nil }
        let display = (try? Data(contentsOf: file(photo.id, .display))) ?? Data()
        return ProcessedPhoto(imageData: full, thumbnailData: thumb, pixelWidth: photo.pixelWidth,
                              pixelHeight: photo.pixelHeight, imageType: photo.imageType, displayData: display)
    }

    /// Removes the draft and every photo it kept.
    func clear() {
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(at: photoDirectory)
    }

    private func prepareDirectories() throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: photoDirectory, withIntermediateDirectories: true,
                                        attributes: [.protectionKey: FileProtectionType.complete])
        var draftFolder = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try draftFolder.setResourceValues(values)
    }

    private func file(_ id: UUID, _ rendition: Rendition) -> URL {
        photoDirectory.appending(path: "\(id.uuidString).\(rendition.rawValue)")
    }

    private func removeFiles(except kept: Set<UUID>) {
        let fileManager = FileManager.default
        guard let names = try? fileManager.contentsOfDirectory(atPath: photoDirectory.path(percentEncoded: false)) else { return }
        for name in names {
            guard let id = UUID(uuidString: String(name.prefix(36))), !kept.contains(id) else { continue }
            try? fileManager.removeItem(at: photoDirectory.appending(path: name))
        }
    }
}
