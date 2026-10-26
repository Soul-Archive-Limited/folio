import SwiftUI

/// The 12 category colours (SPEC §3.2). Stored on `Category.colorKey` by raw value, so
/// raw values must never change once shipped.
nonisolated enum CategoryColor: String, CaseIterable, Identifiable, Sendable {
    case ember, coral, rose, plum, violet, indigo, ocean, teal, sage, olive, sand, graphite

    var id: Self { self }

    @MainActor var color: Color { Color(resource) }

    @MainActor var resource: ColorResource {
        switch self {
        case .ember: .categoryEmber
        case .coral: .categoryCoral
        case .rose: .categoryRose
        case .plum: .categoryPlum
        case .violet: .categoryViolet
        case .indigo: .categoryIndigo
        case .ocean: .categoryOcean
        case .teal: .categoryTeal
        case .sage: .categorySage
        case .olive: .categoryOlive
        case .sand: .categorySand
        case .graphite: .categoryGraphite
        }
    }

    var displayName: LocalizedStringResource {
        switch self {
        case .ember: "Ember"
        case .coral: "Coral"
        case .rose: "Rose"
        case .plum: "Plum"
        case .violet: "Violet"
        case .indigo: "Indigo"
        case .ocean: "Ocean"
        case .teal: "Teal"
        case .sage: "Sage"
        case .olive: "Olive"
        case .sand: "Sand"
        case .graphite: "Graphite"
        }
    }

    /// Unknown keys (e.g. from a newer app version) fall back to graphite.
    init(key: String) {
        self = CategoryColor(rawValue: key) ?? .graphite
    }
}
