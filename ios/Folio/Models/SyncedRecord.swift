import Foundation
import FolioCrypto

/// Fields every synced model shares (SPEC §5).
///
/// `isTombstone` is SPEC's `isDeleted`: SwiftData models already have a built-in
/// `isDeleted` (context deletion state), so the sync flag needs its own name.
nonisolated protocol SyncedRecord: AnyObject {
    static var recordType: RecordType { get }

    var id: UUID { get }
    var createdAt: Date { get }
    var updatedAt: Date { get set }
    /// Last version the server acknowledged; nil if never synced.
    var serverVersion: Int64? { get set }
    /// A local change not yet pushed.
    var isDirty: Bool { get set }
    /// Deleted locally, kept until the server acknowledges, then purged.
    var isTombstone: Bool { get set }
}

nonisolated extension SyncedRecord {
    /// Call after every local change.
    func markChanged(at date: Date) {
        updatedAt = date
        isDirty = true
    }
}
