import SwiftUI

/// The two Recently Deleted toasts (SPEC §5.2), using the normal toast system and placement.
extension ToastMessage {
    /// "Moved to Recently Deleted · Undo".
    static func movedToTrash(undo: @escaping @MainActor () -> Void) -> ToastMessage {
        ToastMessage(text: "Moved to Recently Deleted", systemImage: "trash", undo: ToastUndo(perform: undo))
    }

    /// "Restored to Tue 27 Oct · Show", or "Restored · Show" for an undated task. Show jumps
    /// to the day (or To-do); categories have nowhere to show, so no button.
    static func restored(to day: DayKey?, show: (@MainActor () -> Void)?) -> ToastMessage {
        let text: LocalizedStringResource = day.map { "Restored to \(Self.shortDay($0))" } ?? "Restored"
        return ToastMessage(text: text, systemImage: "arrow.uturn.backward", undo: show.map { ToastUndo(title: "Show", perform: $0) })
    }

    /// "Tue 27 Oct" in en_GB (the locale decides order and punctuation).
    static func shortDay(_ day: DayKey) -> String {
        DayFormat.string(day, template: "EEEdMMM")
    }
}

/// Formats a floating `DayKey` from a localized template, in GMT so the day never shifts.
enum DayFormat {
    static func string(_ day: DayKey, template: String) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = .gmt
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: day.utcDate)
    }
}
