import SwiftUI

/// One toast (SPEC §6.14): saved / deleted with Undo / sync issues.
struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let text: LocalizedStringResource
    var systemImage: String = "checkmark.circle.fill"
    var undo: ToastUndo?

    static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool { lhs.id == rhs.id }
}

/// The Undo action attached to a toast.
struct ToastUndo {
    var title: LocalizedStringResource = "Undo"
    let perform: @MainActor () -> Void
}
