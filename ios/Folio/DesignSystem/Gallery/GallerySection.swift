#if DEBUG
import SwiftUI

/// Title + content block used by every gallery section.
struct GallerySection<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(title)
                .folioFont(.caption)
                .foregroundStyle(.inkTertiary)
                .accessibilityAddTraits(.isHeader)
            content
        }
    }
}
#endif
