import Foundation

/// The JSON shape of `Folio Export.json` (SPEC §6.9).
nonisolated struct ExportDocument: Codable, Sendable {
    var format = "folio-export-1"
    let exportedAt: Date
    let appVersion: String
    let displayName: String
    let categories: [ExportCategory]
    let entries: [ExportEntry]
    let tasks: [ExportTask]
}

nonisolated struct ExportCategory: Codable, Sendable {
    let id: UUID
    let name: String
    let color: String
    let symbol: String?
    let sortIndex: Int
    /// Set only for items exported from Recently Deleted.
    var trashedAt: Date?
}

nonisolated struct ExportEntry: Codable, Sendable {
    let id: UUID
    let day: String
    let minutesFromMidnight: Int?
    let title: String
    let bodyMarkdown: String
    let categoryID: UUID?
    /// File names inside `Folio Photos.zip`, in order.
    let photos: [String]
    let createdAt: Date
    let updatedAt: Date
    var trashedAt: Date?
}

nonisolated struct ExportTask: Codable, Sendable {
    let id: UUID
    let title: String
    let notes: String?
    let day: String?
    let minutesFromMidnight: Int?
    let categoryID: UUID?
    let isCompleted: Bool
    let completedAt: Date?
    var trashedAt: Date?
}
