import SwiftUI

/// Liquid Glass with Folio's accessibility fallbacks (SPEC §3.4, §3.9).
///
/// - Default: system `.glassEffect(.regular)`; `.interactive()` only for tappable surfaces.
/// - Reduce Transparency: a solid `bgElevated` fill with a hairline border instead of glass.
/// - Increase Contrast: adds a hairline border so the edge stays visible.
/// - `solidFill`: draws an opaque fill instead of glass (selected chips), so labels on it
///   keep a guaranteed contrast ratio.
struct FolioGlassModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    var interactive = false
    var tint: Color?
    var solidFill: Color?

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        if let solidFill {
            content.background(solidFill, in: shape)
        } else if reduceTransparency {
            content
                .background(tint ?? .bgElevated, in: shape)
                .overlay { shape.strokeBorder(.hairline, lineWidth: 1) }
        } else {
            content
                .glassEffect(glass, in: shape)
                .overlay { shape.strokeBorder(.hairline, lineWidth: contrast == .increased ? 1 : 0) }
        }
    }

    private var glass: Glass {
        var glass = Glass.regular
        if let tint { glass = glass.tint(tint) }
        if interactive { glass = glass.interactive() }
        return glass
    }
}

extension View {
    /// Applies Folio glass in `shape`. Apply after padding, frame and other layout modifiers.
    func folioGlass<S: InsettableShape>(
        in shape: S, interactive: Bool = false, tint: Color? = nil, solidFill: Color? = nil
    ) -> some View {
        modifier(FolioGlassModifier(shape: shape, interactive: interactive, tint: tint, solidFill: solidFill))
    }
}
