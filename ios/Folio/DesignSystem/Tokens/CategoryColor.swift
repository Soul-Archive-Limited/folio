import SwiftUI

/// The 12 category colours (SPEC §3.2). Stored on `Category.colorKey` by raw value, so
/// raw values must never change once shipped: Amber is still stored as "ember" (Batch K's
/// rebrand renamed it and moved it down so the accent-like Indigo comes first).
nonisolated enum CategoryColor: String, CaseIterable, Identifiable, Sendable {
    case indigo, ocean, teal, sage, violet, plum, rose, coral
    case amber = "ember"
    case sand, olive, graphite

    var id: Self { self }

    @MainActor var color: Color { Color(resource) }

    @MainActor var resource: ColorResource {
        switch self {
        case .amber: .categoryEmber
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
        case .amber: "Amber"
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
