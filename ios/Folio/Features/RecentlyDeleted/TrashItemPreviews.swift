import SwiftUI

/// A trashed entry as it will look when restored: photos, day, category, title, body.
struct TrashEntryPreview: View {
    let entry: Entry
    @Environment(DiaryStore.self) private var store

    var body: some View {
        let photos = entry.orderedPhotos
        if !photos.isEmpty {
            PhotoCarousel(photoIDs: photos.map(\.id)) { _ in }
        }
        if let day = entry.day {
            Text(TrashRowData.longDay(day)).folioFont(.caption).foregroundStyle(.inkTertiary)
        }
        if let category = store.category(id: entry.categoryID) {
            CategoryTag(category: category)
        }
        Text(entry.displayTitle).folioFont(.title2).foregroundStyle(.ink).accessibilityAddTraits(.isHeader)
        EntryBodyText(markdown: entry.bodyMarkdown,
                      writingFont: WritingFont(rawValue: store.settings().writingFont) ?? .newYork)
    }
}

/// A trashed task: done state, title, notes, day and category.
struct TrashTaskPreview: View {
    let task: TaskItem
    @Environment(DiaryStore.self) private var store

    var body: some View {
        Label(task.isCompleted ? "Done" : "Not done", systemImage: task.isCompleted ? "checkmark.circle.fill" : "circle")
            .folioFont(.caption)
            .foregroundStyle(task.isCompleted ? .done : .inkTertiary)
        Text(task.title).folioFont(.title2).foregroundStyle(.ink).accessibilityAddTraits(.isHeader)
        if let notes = task.notes, !notes.isEmpty {
            Text(notes).folioFont(.body).foregroundStyle(.inkSecondary)
        }
        Text(task.day.map(TrashRowData.longDay) ?? String(localized: "No date"))
            .folioFont(.callout).foregroundStyle(.inkSecondary)
        if let category = store.category(id: task.categoryID) {
            CategoryTag(category: category)
        }
    }
}

/// A trashed category: its chip and what a restore re-links.
struct TrashCategoryPreview: View {
    let category: Category

    var body: some View {
        Chip(title: category.name, systemImage: category.symbol, category: category.color, isSelected: true) {}
            .allowsHitTesting(false)
        let count = category.unassignedIDs?.count ?? 0
        Text(count == 0
             ? String(localized: "Nothing used this category.")
             : String(AttributedString(localized: "Restoring it puts it back on ^[\(count) item](inflect: true) that used it.").characters))
            .folioFont(.body)
            .foregroundStyle(.inkSecondary)
    }
}
