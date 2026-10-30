import SwiftUI

/// Makes a half sheet read as a layer above the screen (owner's test, Batch I): the screen
/// behind dims a little, most toward the sheet's edge, like a soft shadow. Taps pass through,
/// so the calendar above a medium sheet stays usable (SPEC §6.4).
struct SheetBackdropDim: View {
    let isVisible: Bool

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let strength = colorScheme == .dark ? 0.34 : 0.16
        LinearGradient(stops: [.init(color: .black.opacity(strength * 0.35), location: 0),
                               .init(color: .black.opacity(strength), location: 0.55),
                               .init(color: .black.opacity(strength * 1.2), location: 1)],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
            .opacity(isVisible ? 1 : 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .animation(reduceMotion ? FolioMotion.reduced : .smooth(duration: 0.35), value: isVisible)
    }
}

/// The composer sheet's surface: a stronger material than the default sheet glass, with a fine
/// highlight along the top edge so the edge reads against the screen behind it.
struct SheetSurface: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Rectangle()
            .fill(.thickMaterial)
            .overlay(Color.bgElevated.opacity(colorScheme == .dark ? 0.35 : 0.55))
            .overlay(alignment: .top) {
                LinearGradient(colors: [.white.opacity(colorScheme == .dark ? 0.22 : 0.9), .white.opacity(0)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 1.5)
            }
    }
}
