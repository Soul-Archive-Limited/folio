import SwiftUI

/// Theme setting (SPEC §3.2): follow the system, or force light or dark.
nonisolated enum AppearancePreference: String, CaseIterable, Sendable {
    case system, light, dark

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
