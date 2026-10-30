import SwiftUI

/// The "Recently Deleted · N" button at the end of the Journal timeline and the To-do list
/// (SPEC §5.2): small, in the accent colour, so it reads as a button (Batch I). Shown only when
/// something is in the trash.
struct RecentlyDeletedLink: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Recently Deleted · \(count)", systemImage: "trash")
                .folioFont(.callout)
                .fontWeight(.medium)
                .padding(.horizontal, Spacing.s)
                .frame(minHeight: 34)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: 10))
        .tint(.emberStrong)
        .frame(maxWidth: .infinity, minHeight: Spacing.minHitTarget)
        .accessibilityLabel("Recently Deleted, \(count) items")
        .accessibilityIdentifier("recently-deleted-link")
    }
}
