#if DEBUG
import SwiftUI

struct GalleryColorsSection: View {
    private let tokens: [(String, ColorResource)] = [
        ("bg", .bg), ("bgElevated", .bgElevated), ("ink", .ink), ("inkSecondary", .inkSecondary),
        ("inkTertiary", .inkTertiary), ("hairline", .hairline), ("ember", .ember), ("done", .done),
        ("danger", .danger), ("aura1", .aura1), ("aura2", .aura2), ("aura3", .aura3),
    ]

    var body: some View {
        GallerySection(title: "Colour tokens") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: Spacing.s)], spacing: Spacing.s) {
                ForEach(tokens, id: \.0) { name, resource in
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        RoundedRectangle(cornerRadius: Radius.dayCell)
                            .fill(Color(resource))
                            .strokeBorder(.hairline, lineWidth: 1)
                            .frame(height: 48)
                        Text(name).folioFont(.micro).foregroundStyle(.inkSecondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}
#endif
