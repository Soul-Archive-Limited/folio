import Foundation
import os

/// One draft on disk, inside the protected store directory and written with
/// `.completeFileProtection` — a draft is diary text too (SPEC §13.9).
nonisolated struct DraftStore: Sendable {
    var directory: URL = FolioPersistence.storeDirectory.appending(path: "Drafts", directoryHint: .isDirectory)

    private var url: URL { directory.appending(path: "composer.json") }
    private static let logger = Logger(subsystem: "com.devilsense.folio", category: "drafts")

    func load() -> ComposerDraft? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ComposerDraft.self, from: data)
    }

    func save(_ draft: ComposerDraft) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                    attributes: [.protectionKey: FileProtectionType.complete])
            try JSONEncoder().encode(draft).write(to: url, options: [.atomic, .completeFileProtection])
        } catch {
            Self.logger.error("Draft save failed: \(String(describing: type(of: error)), privacy: .public)")
        }
    }

    func clear() {
        try? FileManager.default.removeItem(at: url)
    }
}
