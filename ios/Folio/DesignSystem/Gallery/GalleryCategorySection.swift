#if DEBUG
import SwiftUI

struct GalleryCategorySection: View {
    @Environment(\.self) private var environment

    var body: some View {
        GallerySection(title: "Category palette · auto-contrast labels") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: Spacing.s)], spacing: Spacing.s) {
                ForEach(CategoryColor.allCases) { category in
                    Text(category.displayName)
                        .folioFont(.headline)
                        .foregroundStyle(ContrastLabel.color(on: category.color, in: environment))
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(category.color, in: .rect(cornerRadius: Radius.dayCell))
                }
            }
        }
    }
}
#endif
