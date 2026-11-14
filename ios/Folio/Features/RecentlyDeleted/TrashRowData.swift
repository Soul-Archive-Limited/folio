import SwiftUI

/// What a Recently Deleted row shows: the item, its original date and how long it has left.
struct TrashRowData: Identifiable {
    let item: TrashItem
    let title: String
    /// The original day ("Tue 27 Oct 2026"), "No date", or what a category held.
    let detail: String
    let daysLeft: Int
    let systemImage: String
    var tint: Color = .inkSecondary
    var isCompleted = false

    var id: UUID { item.id }

    /// "Tue 27 Oct 2026" in en_GB.
    static func longDay(_ day: DayKey) -> String {
        DayFormat.string(day, template: "EEEdMMMyyyy")
    }
}

extension DiaryStore {
    /// Rows for one segment of Recently Deleted, most recently deleted first.
    func trashRows(_ kind: TrashKind) -> [TrashRowData] {
        switch kind {
        case .entries:
            trashedEntries().map { entry in
                let photos = entry.orderedPhotos.count
                var detail = entry.day.map(TrashRowData.longDay) ?? ""
                if photos > 0 { detail += " · " + String(AttributedString(localized: "^[\(photos) photo](inflect: true)").characters) }
                return TrashRowData(item: TrashItem(kind: .entries, id: entry.id), title: entry.displayTitle, detail: detail,
                                    daysLeft: daysLeft(trashedAt: entry.trashedAt ?? now()),
                                    systemImage: photos > 0 ? "photo" : "doc.text")
            }
        case .tasks:
            trashedTasks().map { task in
                TrashRowData(item: TrashItem(kind: .tasks, id: task.id), title: task.title,
                             detail: task.day.map(TrashRowData.longDay) ?? String(localized: "No date"),
                             daysLeft: daysLeft(trashedAt: task.trashedAt ?? now()),
                             systemImage: task.isCompleted ? "checkmark.circle.fill" : "circle",
                             tint: task.isCompleted ? .done : .inkSecondary, isCompleted: task.isCompleted)
            }
        case .categories:
            trashedCategories().map { category in
                let count = category.unassignedIDs?.count ?? 0
                return TrashRowData(item: TrashItem(kind: .categories, id: category.id), title: category.name,
                                    detail: String(AttributedString(localized: "Was on ^[\(count) item](inflect: true)").characters),
                                    daysLeft: daysLeft(trashedAt: category.trashedAt ?? now()),
                                    systemImage: category.symbol ?? "circle.fill", tint: category.color.color)
            }
        }
    }
}

extension Entry {
    /// What a page is called wherever it's listed (Batch O, owner: never "Untitled"): the title,
    /// else the first line of its words, else "A photo" / "3 photos", else "Empty page".
    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let firstLine = MarkdownCodec.document(from: bodyMarkdown).plainText
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""
        if !firstLine.isEmpty { return String(firstLine.prefix(80)) }
        return Self.untitledName(photoCount: orderedPhotos.count)
    }

    /// The name for a page with no words at all.
    static func untitledName(photoCount: Int) -> String {
        switch photoCount {
        case 0: String(localized: "Empty page")
        case 1: String(localized: "A photo")
        default: String(localized: "\(photoCount) photos")
        }
    }
}
