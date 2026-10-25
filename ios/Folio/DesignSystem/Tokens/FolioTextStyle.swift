import SwiftUI

/// Type scale (SPEC §3.3). Every style scales with Dynamic Type.
///
/// Styles that match a system text style at its default size use that text style directly,
/// so they get Apple's own Dynamic Type curve. `display` and `micro` have no system
/// equivalent and scale with `@ScaledMetric` instead.
enum FolioTextStyle: CaseIterable, Sendable {
    case display, title1, title2, headline, body, callout, caption, micro

    var name: String {
        switch self {
        case .display: "Display"
        case .title1: "Title 1"
        case .title2: "Title 2"
        case .headline: "Headline"
        case .body: "Body"
        case .callout: "Callout"
        case .caption: "Caption"
        case .micro: "Micro"
        }
    }
}

extension View {
    /// Applies a Folio type style, including its tracking and case.
    func folioFont(_ style: FolioTextStyle) -> some View {
        modifier(FolioTextStyleModifier(style: style))
    }
}
