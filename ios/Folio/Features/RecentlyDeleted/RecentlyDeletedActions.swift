import SwiftUI

/// Restore and Delete now for Recently Deleted (SPEC §5.2), with the restore toast.
@MainActor
struct RecentlyDeletedActions {
    let store: DiaryStore
    let toasts: ToastCenter?
    let router: TabRouter?

    /// One item: "Restored to Tue 27 Oct · Show". Several: "Restored 3 items".
    func restore(_ items: [TrashItem]) {
        var restored = 0
        var last: (day: DayKey?, isTask: Bool)?
        var blocked = false
        for item in items {
            switch item.kind {
            case .entries:
                guard let entry = store.trashedEntries().first(where: { $0.id == item.id }) else { continue }
                store.restoreFromTrash(entry)
                last = (entry.day, false)
            case .tasks:
                guard let task = store.trashedTasks().first(where: { $0.id == item.id }) else { continue }
                store.restoreFromTrash(task)
                last = (task.day, true)
            case .categories:
                guard let category = store.trashedCategories().first(where: { $0.id == item.id }) else { continue }
                do { try store.restoreFromTrash(category) } catch { blocked = true; continue }
                last = (nil, false)
            }
            restored += 1
        }
        if blocked {
            toasts?.show(ToastMessage(text: "You already have 30 categories.", systemImage: "exclamationmark.triangle"))
        } else if restored > 1 {
            toasts?.show(ToastMessage(text: "Restored \(restored) items", systemImage: "arrow.uturn.backward"))
        } else if let last {
            toasts?.show(.restored(to: last.day, show: showAction(day: last.day, isTask: last.isTask)))
        }
    }

    func deleteNow(_ items: [TrashItem]) {
        for item in items {
            switch item.kind {
            case .entries: store.trashedEntries().first { $0.id == item.id }.map(store.deletePermanently)
            case .tasks: store.trashedTasks().first { $0.id == item.id }.map(store.deletePermanently)
            case .categories: store.trashedCategories().first { $0.id == item.id }.map(store.deletePermanently)
            }
        }
    }

    /// Show jumps to the day on the calendar; an undated task opens To-do; a category has
    /// nowhere to show.
    private func showAction(day: DayKey?, isTask: Bool) -> (@MainActor () -> Void)? {
        guard let router else { return nil }
        if let day { return { router.open(.day(day)) } }
        guard isTask else { return nil }
        return { router.open(.todo) }
    }
}
