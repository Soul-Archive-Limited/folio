import SwiftUI
import UIKit

/// Folio's tokens for the widget extension (SPEC §3.2), which doesn't carry the app's asset
/// catalog: the same light/dark values, as dynamic colours.
enum WidgetPalette {
    static let bg = dynamic(light: "F6F3EC", dark: "141418")
    static let ink = dynamic(light: "17161C", dark: "F3F2F0")
    /// Ink (Batch K): marks and glyphs; `accentStrong` under white text; `accentText` for words.
    static let accent = dynamic(light: "3441D5", dark: "949FFF")
    static let accentStrong = dynamic(light: "303ECF", dark: "4551D3")
    static let accentText = dynamic(light: "303AC0", dark: "9EA8FF")
    static let done = dynamic(light: "2FA35A", dark: "7ED69B")
    static let aura = dynamic(light: "B8C0FF", dark: "3441D5")

    static func tint(light: String?, dark: String?) -> Color? {
        guard let light, let dark else { return nil }
        return dynamic(light: light, dark: dark)
    }

    /// "RRGGBB|RRGGBB" from the snapshot's dots.
    static func pair(_ value: String) -> Color? {
        let parts = value.split(separator: "|").map(String.init)
        guard parts.count == 2 else { return nil }
        return dynamic(light: parts[0], dark: parts[1])
    }

    static func dynamic(light: String, dark: String) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? uiColor(dark) : uiColor(light) })
    }

    private static func uiColor(_ hex: String) -> UIColor {
        let value = UInt32(hex, radix: 16) ?? 0
        return UIColor(red: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
                       blue: CGFloat(value & 0xFF) / 255, alpha: 1)
    }
}

/// The widgets' background: Folio's page colour with a soft accent glow, like the aura.
struct WidgetBackground: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            WidgetPalette.bg
            Circle()
                .fill(WidgetPalette.aura.opacity(0.22))
                .frame(width: 220, height: 220)
                .blur(radius: 60)
                .offset(x: -70, y: -90)
        }
    }
}

extension WidgetSnapshot.Task {
    var timeText: String? {
        guard let minutes else { return nil }
        return String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
}
