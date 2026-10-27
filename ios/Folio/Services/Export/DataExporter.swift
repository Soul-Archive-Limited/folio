import Foundation
import os

/// "Export as JSON + photos zip" (SPEC §6.9): everything decrypted, made locally, handed to
/// the share sheet and deleted afterwards. Nothing leaves the phone unless the user sends it.
///
/// - `Folio Export.json`: settings, categories, entries (Markdown bodies) and tasks.
/// - `Folio Photos.zip`: every photo at full size, named by day, from a folder zipped with
///   `NSFileCoordinator` (the system's own zip; no third-party code).
struct DataExporter {
    let store: DiaryStore
    /// "Include Recently Deleted" (SPEC §5.2): off by default; trashed items then carry `trashedAt`.
    var includesTrash = false
    var directory = URL.temporaryDirectory.appending(path: "FolioExport-\(UUID().uuidString)", directoryHint: .isDirectory)

    enum ExportError: Error { case zipFailed }

    private static let logger = Logger(subsystem: "com.devilsense.folio", category: "export")

    /// Writes the files and returns their URLs, JSON first.
    func export() async throws -> [URL] {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true,
                                        attributes: [.protectionKey: FileProtectionType.complete])
        let photoFolder = directory.appending(path: "Folio Photos", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: photoFolder, withIntermediateDirectories: true)

        var entries: [ExportEntry] = []
        let allEntries = store.allEntries() + (includesTrash ? store.trashedEntries() : [])
        for entry in allEntries {
            var photoNames: [String] = []
            for (index, photo) in entry.orderedPhotos.enumerated() {
                let name = "\(entry.dayKey) \(entry.id.uuidString.prefix(8)) \(index + 1).heic"
                try photo.imageData.write(to: photoFolder.appending(path: name), options: .completeFileProtection)
                photoNames.append(name)
                await Task.yield()
            }
            entries.append(ExportEntry(id: entry.id, day: entry.dayKey, minutesFromMidnight: entry.minutesFromMidnight,
                                       title: entry.title, bodyMarkdown: entry.bodyMarkdown, categoryID: entry.categoryID,
                                       photos: photoNames, createdAt: entry.createdAt, updatedAt: entry.updatedAt,
                                       trashedAt: entry.trashedAt))
        }
        let settings = store.settings()
        let document = ExportDocument(
            exportedAt: AppClock.now,
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
            displayName: settings.displayName,
            categories: (store.categories() + (includesTrash ? store.trashedCategories() : [])).map {
                ExportCategory(id: $0.id, name: $0.name, color: $0.colorKey, symbol: $0.symbol, sortIndex: $0.sortIndex,
                               trashedAt: $0.trashedAt)
            },
            entries: entries,
            tasks: (store.allTasks() + (includesTrash ? store.trashedTasks() : [])).map {
                ExportTask(id: $0.id, title: $0.title, notes: $0.notes, day: $0.dayKey, minutesFromMidnight: $0.minutesFromMidnight,
                           categoryID: $0.categoryID, isCompleted: $0.isCompleted, completedAt: $0.completedAt,
                           trashedAt: $0.trashedAt)
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let jsonURL = directory.appending(path: "Folio Export.json")
        try encoder.encode(document).write(to: jsonURL, options: .completeFileProtection)

        let zipURL = directory.appending(path: "Folio Photos.zip")
        try zip(photoFolder, to: zipURL)
        try? fileManager.removeItem(at: photoFolder)
        return [jsonURL, zipURL]
    }

    /// Removes the export once the share sheet is done with it.
    func cleanUp() {
        try? FileManager.default.removeItem(at: directory)
    }

    private func zip(_ folder: URL, to destination: URL) throws {
        var coordinatorError: NSError?
        var copyError: (any Error)?
        NSFileCoordinator().coordinate(readingItemAt: folder, options: .forUploading, error: &coordinatorError) { zipped in
            do { try FileManager.default.copyItem(at: zipped, to: destination) } catch { copyError = error }
        }
        if coordinatorError != nil || copyError != nil {
            Self.logger.error("Photo zip failed")
            throw ExportError.zipFailed
        }
    }
}
