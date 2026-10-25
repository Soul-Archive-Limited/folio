import Foundation

/// Spacing scale (SPEC §3.4). Use these instead of literal numbers.
enum Spacing {
    static let xxs: Double = 4
    static let xs: Double = 8
    static let s: Double = 12
    static let m: Double = 16
    static let l: Double = 20
    static let xl: Double = 24
    static let xxl: Double = 32
    static let xxxl: Double = 40

    /// Leading/trailing screen margin.
    static let sideMargin: Double = 20
    /// Minimum hit area for any tappable element (SPEC §3.9).
    static let minHitTarget: Double = 44
}
