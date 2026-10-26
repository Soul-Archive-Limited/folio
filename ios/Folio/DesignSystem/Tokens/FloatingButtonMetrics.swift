import Foundation

/// Geometry of the floating glass "+" button (SPEC §2), shared by the button and by the
/// greeting mark that travels toward it.
enum FloatingButtonMetrics {
    static let diameter: Double = 56
    /// Distance from the screen's trailing edge to the button's centre.
    static let centerInsetTrailing: Double = Spacing.sideMargin + diameter / 2
    /// Distance from the screen's bottom edge to the button's centre: home indicator (34) +
    /// tab bar (49) + gap (16) + radius. Measured on iPhone 17 Pro: 127 pt.
    static let centerInsetBottom: Double = 34 + 49 + Spacing.m + diameter / 2
}
