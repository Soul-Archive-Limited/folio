import SwiftUI

/// Read-only preview of a trashed item with Restore and Delete now (SPEC §5.2).
struct TrashPreviewSheet: View {
    let item: TrashItem
    let actions: RecentlyDeletedActions

    @Environment(DiaryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var confirmsDelete = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.sideMargin)
                .padding(.bottom, Spacing.xl)
            }
            .navigationTitle("Recently Deleted")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close", systemImage: "xmark") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) { buttons }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.thickMaterial)
        .privacyCovered()
        .confirmationDialog("Delete this for good?", isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                actions.deleteNow([item])
                dismiss()
            }
        } message: {
            Text("This can't be undone.")
        }
        .folioHaptic(.warning, trigger: confirmsDelete)
    }

    @ViewBuilder private var content: some View {
        switch item.kind {
        case .entries:
            if let entry = store.trashedEntry(id: item.id) { TrashEntryPreview(entry: entry) }
        case .tasks:
            if let task = store.trashedTasks().first(where: { $0.id == item.id }) { TrashTaskPreview(task: task) }
        case .categories:
            if let category = store.trashedCategories().first(where: { $0.id == item.id }) {
                TrashCategoryPreview(category: category)
            }
        }
    }

    private var buttons: some View {
        GlassEffectContainer(spacing: Spacing.s) {
            HStack(spacing: Spacing.s) {
                Button {
                    dismiss()
                    actions.restore([item])
                } label: {
                    Label("Restore", systemImage: "arrow.uturn.backward").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(.ember)
                Button(role: .destructive) { confirmsDelete = true } label: {
                    Label("Delete now", systemImage: "trash").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
            }
            .controlSize(.large)
        }
        .padding(.horizontal, Spacing.sideMargin)
        .padding(.top, Spacing.s)
        .padding(.bottom, Spacing.s)
        // Text fades out under the buttons instead of running behind them.
        .background {
            Rectangle().fill(.thickMaterial)
                .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.35)],
                                     startPoint: .top, endPoint: .bottom))
                .padding(.top, -Spacing.l)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }
}
