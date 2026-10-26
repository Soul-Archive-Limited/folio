import SwiftData

/// Schema version 1. Every future model change adds a new `VersionedSchema` and a stage
/// in `FolioMigrationPlan` (swiftdata-pro: always have a migration plan).
enum FolioSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Category.self, Entry.self, EntryPhoto.self, TaskItem.self, UserSettings.self]
    }
}

enum FolioMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [FolioSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
