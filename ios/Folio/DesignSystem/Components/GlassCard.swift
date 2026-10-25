import SwiftUI

/// A glass card with the standard 22 pt radius (SPEC §3.4). Nested shapes can use
/// `ConcentricRectangle()` to follow the card's corners.
struct GlassCard<Content: View>: View {
    var padding: Double = Spacing.m
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .containerShape(.rect(cornerRadius: Radius.card))
            .folioGlass(in: .rect(cornerRadius: Radius.card))
    }
}

#Preview {
    ZStack {
        AuraBackground()
        GlassCard {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Saturday, 25 October").folioFont(.title2)
                Text("A long walk by the river, then soup.").folioFont(.callout).foregroundStyle(.inkSecondary)
            }
        }
        .padding(Spacing.sideMargin)
    }
}
