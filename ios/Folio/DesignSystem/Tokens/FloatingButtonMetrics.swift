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
    /// Space a scrolling list leaves above the tab bar so the floating "+" never sits on a
    /// row: the button plus its 16 pt gap (owner review, Batch A).
    static let clearance: Double = diameter + Spacing.m

    /// Toasts rest just above the tab bar, centred on the "+" row (toast 52 pt, button 56 pt).
    /// Measured from the tab content's bottom edge, which is already above the tab bar.
    static let toastBottomPadding: Double = Spacing.m + 2
    /// Room a toast leaves on its trailing side when it shares the row with the "+".
    static let toastTrailingClearance: Double = diameter + Spacing.s
}
