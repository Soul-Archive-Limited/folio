import SwiftUI

/// Limits the editor to Folio's styles (SPEC §5.1): system formatting controls and pasted
/// text can only ever produce single underline/strikethrough, the highlight colour and the
/// prefix colours. Fonts are normalised on save by `RichTextBridge`.
struct FolioFormattingDefinition: AttributedTextFormattingDefinition {
    typealias Scope = AttributeScopes.SwiftUIAttributes

    var body: some AttributedTextFormattingDefinition<Scope> {
        ValueConstraint(for: \.underlineStyle, values: [nil, .single], default: nil)
        ValueConstraint(for: \.strikethroughStyle, values: [nil, .single], default: nil)
        ValueConstraint(for: \.backgroundColor, values: [nil, RichTextBridge.highlightColor], default: nil)
        ValueConstraint(for: \.foregroundColor, values: [nil, RichTextBridge.prefixColor, RichTextBridge.quoteColor], default: nil)
    }
}
