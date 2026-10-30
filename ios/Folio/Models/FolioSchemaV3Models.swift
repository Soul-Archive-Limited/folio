import Foundation
import SwiftData

/// Schema version 3, frozen as it shipped (Batch D–H). TaskItem and UserSettings changed in v4
/// (Batch I: reminders, repeats, subtasks; avatars), so their v3 shapes are copied here. The
/// settings model was unchanged from v1 to v3, so v1 and v2 use this copy too.
extension FolioSchemaV3 {
    @Model nonisolated
    final class TaskItem {
        #Unique<TaskItem>([\.id])
        #Index<TaskItem>([\.dayKey], [\.isTombstone, \.isCompleted])

        var id: UUID
        var title: String
        var notes: String?
        /// `DayKey.rawValue`, or nil for an undated task.
        var dayKey: String?
        var minutesFromMidnight: Int?
        var categoryID: UUID?
        var isCompleted: Bool
        var completedAt: Date?
        var sortIndex: Int

        var createdAt: Date
        var updatedAt: Date
        var serverVersion: Int64?
        var isDirty: Bool
        var isTombstone: Bool
        /// When it was moved to Recently Deleted (SPEC §5.2); nil while live. Added in schema v3.
        var trashedAt: Date?

        init(id: UUID = UUID(), title: String, notes: String? = nil, day: DayKey? = nil, minutesFromMidnight: Int? = nil,
             categoryID: UUID? = nil, sortIndex: Int, now: Date) {
            self.id = id
            self.title = title
            self.notes = notes
            self.dayKey = day?.rawValue
            self.minutesFromMidnight = minutesFromMidnight
            self.categoryID = categoryID
            self.isCompleted = false
            self.completedAt = nil
            self.sortIndex = sortIndex
            self.createdAt = now
            self.updatedAt = now
            self.serverVersion = nil
            self.isDirty = true
            self.isTombstone = false
        }

        var day: DayKey? { dayKey.flatMap(DayKey.init(rawValue:)) }
    }

    @Model nonisolated
    final class UserSettings {
        #Unique<UserSettings>([\.id])


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
            self.id = Folio.UserSettings.singletonID
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
}
