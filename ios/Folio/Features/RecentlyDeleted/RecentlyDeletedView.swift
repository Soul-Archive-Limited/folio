import SwiftUI

/// Recently Deleted (SPEC §5.2): entries, tasks and categories deleted in the last 30 days.
/// Tap to preview, swipe to restore or delete now, Select for several, Empty for all.
struct RecentlyDeletedView: View {
    @Environment(DiaryStore.self) private var store
    @Environment(ToastCenter.self) private var toasts: ToastCenter?
    @Environment(\.tabRouter) private var router
    @State private var kind: TrashKind = .entries
    @State private var editMode: EditMode = .inactive
    @State private var selection = Set<UUID>()
    @State private var previewing: TrashItem?
    @State private var pendingDelete: [TrashItem]?
    @State private var confirmsEmpty = false

    var body: some View {
        let rows = store.trashRows(kind)
        List(selection: $selection) {
            Section {
                if rows.isEmpty {
                    EmptyStateView(systemImage: "trash", message: "Nothing here. Deleted items stay for 30 days.")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.xl)
                        .listRowBackground(Color.clear)
                }
                ForEach(rows) { row in
                    rowView(row)
                        .tag(row.id)
                        .listRowBackground(ProfileRowBackground())
                }
            } header: {
                Picker("Show", selection: $kind) {
                    ForEach(TrashKind.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .textCase(nil)
                .padding(.horizontal, -Spacing.m)
                .padding(.bottom, Spacing.s)
            } footer: {
                if !rows.isEmpty {
                    Text("Items are deleted for good 30 days after you delete them.")
                }
            }
        }
        .environment(\.editMode, $editMode)
        .scrollContentBackground(.hidden)
        .background { AuraBackground() }
        .navigationTitle("Recently Deleted")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar(hasRows: !rows.isEmpty) }
        .safeAreaInset(edge: .bottom) {
            if editMode.isEditing {
                selectionBar(rows: rows)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(FolioMotion.standard(), value: editMode.isEditing)
        .animation(FolioMotion.standard(), value: rows.map(\.id))
        .onChange(of: kind) { selection = [] }
        .sheet(item: $previewing) { item in
            TrashPreviewSheet(item: item, actions: actions)
        }
        .confirmationDialog(deleteTitle, isPresented: isConfirmingDelete, titleVisibility: .visible, presenting: pendingDelete) { items in
            Button(items.count == 1 ? "Delete" : "Delete \(items.count) items", role: .destructive) {
                actions.deleteNow(items)
                finishEditing()
            }
        } message: { _ in
            Text("This can't be undone.")
        }
        .confirmationDialog("Empty Recently Deleted?", isPresented: $confirmsEmpty, titleVisibility: .visible) {
            Button("Delete \(store.trashCount) items", role: .destructive) {
                store.emptyTrash()
                finishEditing()
            }
        } message: {
            Text("Everything in Recently Deleted is deleted for good. This can't be undone.")
        }
        .folioHaptic(.warning, trigger: confirmsEmpty)
        .folioHaptic(.warning, trigger: pendingDelete?.count)
    }

    private var actions: RecentlyDeletedActions {
        RecentlyDeletedActions(store: store, toasts: toasts, router: router)
    }

    @ViewBuilder
    private func rowView(_ row: TrashRowData) -> some View {
        Group {
            if editMode.isEditing {
                TrashRow(row: row)
            } else {
                Button { previewing = row.item } label: { TrashRow(row: row) }
                    .buttonStyle(.plain)
                    .accessibilityHint("Shows a preview with Restore and Delete now")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button("Restore", systemImage: "arrow.uturn.backward") { actions.restore([row.item]) }
                .tint(.done)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            // Not `.destructive`: that removes the row before the confirmation is answered.
            Button("Delete now", systemImage: "trash") { pendingDelete = [row.item] }
                .tint(.danger)
        }
    }

    @ToolbarContentBuilder
    private func toolbar(hasRows: Bool) -> some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if !editMode.isEditing {
                Button("Empty", role: .destructive) { confirmsEmpty = true }
                    .disabled(store.trashCount == 0)
            }
            Button(editMode.isEditing ? "Done" : "Select") {
                if editMode.isEditing { finishEditing() } else { editMode = .active }
            }
            .disabled(!hasRows && !editMode.isEditing)
        }
    }

    private func selectionBar(rows: [TrashRowData]) -> some View {
        let selected = rows.filter { selection.contains($0.id) }.map(\.item)
        return GlassEffectContainer(spacing: Spacing.s) {
            HStack(spacing: Spacing.s) {
                Button {
                    actions.restore(selected)
                    finishEditing()
                } label: {
                    Label("Restore selected", systemImage: "arrow.uturn.backward").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(.emberStrong)
                Button(role: .destructive) { pendingDelete = selected } label: {
                    Label("Delete selected", systemImage: "trash").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
            }
            .controlSize(.large)
            .disabled(selected.isEmpty)
        }
        .padding(.horizontal, Spacing.sideMargin)
        .padding(.bottom, Spacing.s)
    }

    private func finishEditing() {
        editMode = .inactive
        selection = []
    }

    private var deleteTitle: String {
        (pendingDelete?.count ?? 0) > 1 ? String(localized: "Delete these for good?") : String(localized: "Delete this for good?")
    }

    private var isConfirmingDelete: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }
}

#if DEBUG
#Preview {
    NavigationStack { RecentlyDeletedView() }
        .environment(PreviewData.previewStore())
        .environment(ToastCenter())
}
#endif
