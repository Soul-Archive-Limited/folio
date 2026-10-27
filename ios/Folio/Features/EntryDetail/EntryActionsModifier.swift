import SwiftUI

extension View {
    /// Swipe actions (leading Edit, trailing Delete) and a long-press menu (Edit, Change date,
    /// Duplicate, Share, Delete) for an entry card in the day panel and the Journal (owner's
    /// iPhone test, Batch E). Delete moves the entry to Recently Deleted with an Undo toast.
    func entryActions(_ entry: Entry, swipes: Bool = true, cornerRadius: Double = Radius.card) -> some View {
        modifier(EntryActionsModifier(entry: entry, swipes: swipes, cornerRadius: cornerRadius))
    }
}

private struct EntryActionsModifier: ViewModifier {
    let entry: Entry
    let swipes: Bool
    let cornerRadius: Double

    @Environment(DiaryStore.self) private var store
    @Environment(ToastCenter.self) private var toasts
    @Environment(\.newItemRequest) private var request
    @State private var showsDateSheet = false
    @State private var sharesTextAndPhotos = false

    func body(content: Content) -> some View {
        content
            .contextMenu {
                Button("Edit", systemImage: "square.and.pencil", action: edit)
                Button("Change date", systemImage: "calendar") { showsDateSheet = true }
                Button("Duplicate", systemImage: "plus.square.on.square", action: duplicate)
                Menu("Share", systemImage: "square.and.arrow.up") { EntryShareMenu(entry: entry) { sharesTextAndPhotos = true } }
                Divider()
                Button("Delete", systemImage: "trash", role: .destructive, action: delete)
            }
            .modifier(SwipesIfEnabled(enabled: swipes, cornerRadius: cornerRadius,
                                      leading: CardSwipeAction(title: "Edit", systemImage: "square.and.pencil", tint: .inkSecondary, perform: edit),
                                      trailing: CardSwipeAction(title: "Delete", systemImage: "trash", tint: .danger, perform: delete)))
            .sheet(isPresented: $showsDateSheet) { ChangeDateSheet(entry: entry) }
            .textAndPhotosShare(isPresented: $sharesTextAndPhotos, entry: entry)
    }

    private func edit() { request?.send(.editEntry(entry.id)) }

    private func duplicate() {
        if store.duplicate(entry) != nil {
            toasts.show(ToastMessage(text: "Entry duplicated", systemImage: "plus.square.on.square"))
        }
    }

    /// To Recently Deleted; no "Are you sure?" (SPEC §5.2).
    private func delete() {
        let entry = entry
        withAnimation(.smooth) { store.trash(entry) }
        toasts.show(.movedToTrash { [store] in store.restoreFromTrash(entry) })
    }
}

private struct SwipesIfEnabled: ViewModifier {
    let enabled: Bool
    let cornerRadius: Double
    let leading: CardSwipeAction
    let trailing: CardSwipeAction

    func body(content: Content) -> some View {
        if enabled {
            content.cardSwipeActions(leading: leading, trailing: trailing, cornerRadius: cornerRadius)
        } else {
            content
        }
    }
}
