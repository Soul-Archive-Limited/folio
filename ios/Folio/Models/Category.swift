import Foundation
import FolioCrypto
import SwiftData

/// A user category with its own colour (SPEC §5, §6.10).
@Model nonisolated
final class Category: SyncedRecord {
    #Unique<Category>([\.id])

    static let recordType: RecordType = .category
    static let nameLengths = 1...24
    static let maximumCount = 30

    var id: UUID
    var name: String
    /// A `CategoryColor` raw value.
    var colorKey: String
    var symbol: String?
    var sortIndex: Int

    var createdAt: Date
    var updatedAt: Date
    var serverVersion: Int64?
    var isDirty: Bool
    var isTombstone: Bool

    init(id: UUID = UUID(), name: String, color: CategoryColor, symbol: String? = nil, sortIndex: Int, now: Date) {
        self.id = id
        self.name = name
        self.colorKey = color.rawValue
        self.symbol = symbol
        self.sortIndex = sortIndex
        self.createdAt = now
        self.updatedAt = now
        self.serverVersion = nil
        self.isDirty = true
        self.isTombstone = false
    }

    var color: CategoryColor { CategoryColor(key: colorKey) }
}
