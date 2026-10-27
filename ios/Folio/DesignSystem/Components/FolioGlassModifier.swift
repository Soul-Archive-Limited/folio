import SwiftUI

/// Liquid Glass with Folio's accessibility fallbacks (SPEC §3.4, §3.9).
///
/// - Default: system `.glassEffect(.regular)`; `.interactive()` only for tappable surfaces.
/// - Reduce Transparency: a solid `bgElevated` fill with a hairline border instead of glass.
/// - Increase Contrast: adds a hairline border so the edge stays visible.
/// - `solidFill`: draws an opaque fill instead of glass (selected chips), so labels on it
///   keep a guaranteed contrast ratio.
/// - `behindContent`: draws the glass as a background layer that takes no touches. Needed for
///   cards with a `.contextMenu` or swipes: a long press or drag landing on a glass layer
///   never reaches them (found in Batch E).
struct FolioGlassModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    var interactive = false
    var tint: Color?
    var solidFill: Color?
    var behindContent = false

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        if let solidFill {
            content.background(solidFill, in: shape)
        } else if reduceTransparency {
            content
                .background(tint ?? .bgElevated, in: shape)
                .overlay { shape.strokeBorder(.hairline, lineWidth: 1) }
        } else if behindContent {
            // The glass layer takes no touches; the content's own shape does.
            content
                .contentShape(shape)
                .background { Color.clear.glassEffect(glass, in: shape).allowsHitTesting(false) }
                .overlay { shape.strokeBorder(.hairline, lineWidth: contrast == .increased ? 1 : 0) }
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
        in shape: S, interactive: Bool = false, tint: Color? = nil, solidFill: Color? = nil, behindContent: Bool = false
    ) -> some View {
        modifier(FolioGlassModifier(shape: shape, interactive: interactive, tint: tint, solidFill: solidFill, behindContent: behindContent))
    }
}
