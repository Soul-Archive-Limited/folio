import Foundation
import os
import SwiftData

/// Creates the on-device SwiftData store (SPEC §0.4, §13.9).
///
/// The store lives in `Application Support/Folio/`, a directory created with
/// `NSFileProtectionComplete` so the database, its journal and external photo files are
/// unreadable while the device is locked. (The Data Protection entitlement sets the same
/// class app-wide once the app is signed.)
enum FolioPersistence {
    static let logger = Logger(subsystem: "com.devilsense.folio", category: "persistence")

    nonisolated static var storeDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "Folio", directoryHint: .isDirectory)
    }

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: FolioSchemaV1.self)
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else {
            try prepareProtectedDirectory()
            configuration = ModelConfiguration(schema: schema, url: storeDirectory.appending(path: "Folio.store"))
        }
        return try ModelContainer(for: schema, migrationPlan: FolioMigrationPlan.self, configurations: configuration)
    }

    static func prepareProtectedDirectory() throws {
        let fileManager = FileManager.default
        let path = storeDirectory.path(percentEncoded: false)
        if !fileManager.fileExists(atPath: path) {
            try fileManager.createDirectory(at: storeDirectory, withIntermediateDirectories: true,
                                            attributes: [.protectionKey: FileProtectionType.complete])
        }
        // Re-apply on every launch in case the directory predates this code.
        try fileManager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: path)
    }
}
