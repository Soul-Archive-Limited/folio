import Foundation
import FolioCrypto
import SwiftData

/// A to-do (SPEC §5). Completing a task never removes it from its day; only deleting does.
@Model nonisolated
final class TaskItem: TrashableRecord {
    #Unique<TaskItem>([\.id])
    #Index<TaskItem>([\.dayKey], [\.isTombstone, \.isCompleted])

    static let recordType: RecordType = .task
    static let titleLengths = 1...200
    static let maximumNotesLength = 2000

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
