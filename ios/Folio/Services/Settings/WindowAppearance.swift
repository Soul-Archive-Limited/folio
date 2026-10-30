import UIKit

/// Applies the Theme setting to every window of the app, sheets included (SPEC §3.2).
/// `preferredColorScheme(nil)` doesn't hand control back to the system after a forced
/// light/dark until a trait change (the app switcher), so the override goes on the windows.
@MainActor
enum WindowAppearance {
    static func apply(_ preference: AppearancePreference) {
        let style: UIUserInterfaceStyle = switch preference {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            for window in scene.windows where window.overrideUserInterfaceStyle != style {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}
