import SwiftUI

/// The quiet "Recently Deleted · N" link at the end of the Journal timeline and the To-do
/// list (SPEC §5.2). Shown only when something is in the trash.
struct RecentlyDeletedLink: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "trash").accessibilityHidden(true)
                Text("Recently Deleted · \(count)")
            }
            .folioFont(.callout)
            .foregroundStyle(.inkTertiary)
            .frame(maxWidth: .infinity, minHeight: Spacing.minHitTarget)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Recently Deleted, \(count) items")
        .accessibilityIdentifier("recently-deleted-link")
    }
}
