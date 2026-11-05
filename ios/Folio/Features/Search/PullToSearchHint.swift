import SwiftUI

/// The magnifier that grows in above the day panel as it's pulled down (Batch J); full size
/// and filled once a release will open search.
struct PullToSearchHint: View {
    let progress: Double

    var body: some View {
        let clamped = min(max(progress, 0), 1)
        HStack(spacing: Spacing.xs) {
            Image(systemName: clamped >= 1 ? "magnifyingglass.circle.fill" : "magnifyingglass")
            Text(clamped >= 1 ? "Release to search" : "Pull to search")
        }
        .folioFont(.caption)
        .foregroundStyle(clamped >= 1 ? AnyShapeStyle(.ember) : AnyShapeStyle(.inkSecondary))
        .opacity(clamped < 0.25 ? 0 : (clamped - 0.25) / 0.75)
        .scaleEffect(0.8 + 0.2 * clamped)
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
