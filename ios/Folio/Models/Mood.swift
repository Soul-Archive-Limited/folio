import SwiftUI

/// How a day felt, on five steps (Batch J). Optional on every entry. Shown with Folio's own
/// glyph — a circle filling from the bottom — never faces or emoji.
nonisolated enum Mood: Int, CaseIterable, Identifiable, Sendable {
    case heavy = 1, low, steady, good, bright

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .heavy: String(localized: "Heavy")
        case .low: String(localized: "Low")
        case .steady: String(localized: "Steady")
        case .good: String(localized: "Good")
        case .bright: String(localized: "Bright")
        }
    }

    /// How full the glyph is.
    var fill: Double { Double(rawValue) / 5 }

    /// A diverging ramp, cool to warm through a neutral middle, so neighbouring steps read
    /// apart and the ends stand out (Year in Pixels, the glyph). Light and dark via the tokens.
    /// Its own hues (indigo, sand, amber), not the accent: with Ink as the accent (Batch K) an
    /// accent end would sit next to indigo.
    @MainActor var color: Color {
        switch self {
        case .heavy: .categoryIndigo
        case .low: .categoryIndigo.opacity(0.5)
        case .steady: .categorySand.opacity(0.75)
        case .good: .categoryEmber.opacity(0.55)
        case .bright: .categoryEmber
        }
    }
}
