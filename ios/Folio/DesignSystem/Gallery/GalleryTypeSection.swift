#if DEBUG
import SwiftUI

struct GalleryTypeSection: View {
    var body: some View {
        GallerySection(title: "Type scale") {
            GlassCard {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("25").folioFont(.display).monospacedDigit()
                    Text("October").folioFont(.title1)
                    Text("Saturday, 25 October").folioFont(.title2)
                    Text("Morning swim").folioFont(.headline)
                    Text("The water was colder than I expected, but the light was perfect.")
                        .folioFont(.body)
                    Text("Two-line preview of an entry in the day panel.")
                        .folioFont(.callout).foregroundStyle(.inkSecondary)
                    Text("Mon Tue Wed").folioFont(.caption).foregroundStyle(.inkTertiary)
                    Text("14").folioFont(.micro)
                    Divider()
                    Text("Writing font — New York")
                        .font(WritingFont.newYork.font())
                    Text("Writing font — SF Pro")
                        .font(WritingFont.sfPro.font())
                }
            }
        }
    }
}
#endif
