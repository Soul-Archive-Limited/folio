import SwiftUI

/// Picks a label colour for text drawn on a coloured fill so it passes WCAG AA
/// (SPEC §3.2: "labels on category colours auto-switch dark/light").
enum ContrastLabel {
    /// Dark label colour: `ink` in light mode (#16161A).
    static let dark = Color(red: 0x16 / 255, green: 0x16 / 255, blue: 0x1A / 255)
    static let light = Color.white

    /// Returns the label colour with the higher contrast ratio against `fill`.
    static func color(on fill: Color, in environment: EnvironmentValues) -> Color {
        let resolved = fill.resolve(in: environment)
        let luminance = relativeLuminance(red: Double(resolved.red), green: Double(resolved.green), blue: Double(resolved.blue))
        return prefersLightLabel(fillLuminance: luminance) ? light : dark
    }

    static func prefersLightLabel(fillLuminance: Double) -> Bool {
        contrastRatio(fillLuminance, 1) >= contrastRatio(fillLuminance, darkLuminance)
    }

    static let darkLuminance = relativeLuminance(red: 0x16 / 255, green: 0x16 / 255, blue: 0x1A / 255)

    /// WCAG 2.x relative luminance of a gamma-encoded sRGB colour.
    static func relativeLuminance(red: Double, green: Double, blue: Double) -> Double {
        func linear(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    static func contrastRatio(_ a: Double, _ b: Double) -> Double {
        (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}
