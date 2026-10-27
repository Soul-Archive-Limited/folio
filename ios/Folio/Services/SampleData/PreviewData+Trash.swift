#if DEBUG
import Foundation

extension PreviewData {
    /// Puts a few sample items in Recently Deleted, deleted 2–27 days ago, so screenshots show
    /// a range of "days left" (`-FolioTrashSamples YES`).
    static func trashSamples(in store: DiaryStore) {
        guard store.trashCount == 0 else { return }
        let now = store.trashClockNow()
        func ago(_ days: Double) -> Date { now.addingTimeInterval(-days * 86_400) }
        let entries = store.allEntries()
        let withPhoto = entries.first { !$0.orderedPhotos.isEmpty && $0.day != store.today }
        let plain = entries.first { $0.orderedPhotos.isEmpty && $0.day != store.today }
        for (entry, days) in [(withPhoto, 2.0), (plain, 16.0)] {
            guard let entry else { continue }
            store.trash(entry)
            entry.trashedAt = ago(days)
        }
        let tasks = store.allTasks()
        for (task, days) in [(tasks.first { $0.isCompleted }, 5.0), (tasks.first { !$0.isCompleted && $0.notes != nil }, 27.0)] {
            guard let task else { continue }
            store.trash(task)
            task.trashedAt = ago(days)
        }
        if let category = store.categories().last {
            store.trash(category)
            category.trashedAt = ago(9)
        }
        store.commit()
    }
}
#endif
