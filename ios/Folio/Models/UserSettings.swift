import Foundation
import FolioCrypto
import SwiftData

/// Synced user settings, stored as one encrypted record (SPEC §5).
/// Device-only preferences live in `@AppStorage` (see `PreferenceKeys`).
@Model nonisolated
final class UserSettings: SyncedRecord {
    #Unique<UserSettings>([\.id])

    static let recordType: RecordType = .settings
    /// There is exactly one settings record per user, always with this id.
    static let singletonID = UUID(uuidString: "00000000-0000-4000-8000-000000000001") ?? UUID()

    var id: UUID
    var displayName: String
    /// `AppearancePreference` raw value.
    var appearance: String
    /// `WritingFont` raw value.
    var writingFont: String
    /// 1 = Sunday … 7 = Saturday; nil follows the locale.
    var firstWeekday: Int?
    var defaultCategoryID: UUID?

    var createdAt: Date
    var updatedAt: Date
    var serverVersion: Int64?
    var isDirty: Bool
    var isTombstone: Bool

    init(now: Date) {
        self.id = Self.singletonID
        self.displayName = ""
        self.appearance = AppearancePreference.system.rawValue
        self.writingFont = WritingFont.newYork.rawValue
        self.firstWeekday = nil
        self.defaultCategoryID = nil
        self.createdAt = now
        self.updatedAt = now
        self.serverVersion = nil
        self.isDirty = true
        self.isTombstone = false
    }
}
