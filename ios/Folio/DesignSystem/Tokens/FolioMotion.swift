import SwiftUI

/// Spring motion tokens (SPEC §3.6). Every animation in the app comes from here.
///
/// Pass `reduceMotion` from `@Environment(\.accessibilityReduceMotion)`. Under Reduce
/// Motion every token becomes a short cross-fade-friendly ease (≤ 0.2 s); pair it with
/// `FolioMotion.transition(_:reduceMotion:)` so movement is replaced by opacity.
enum FolioMotion {
    /// Default for state changes and most transitions.
    static func standard(reduceMotion: Bool = false) -> Animation {
        reduceMotion ? reduced : .smooth(duration: 0.35)
    }

    /// For anything driven by or answering a gesture.
    static func interactive(reduceMotion: Bool = false) -> Animation {
        reduceMotion ? reduced : .snappy
    }

    /// For confirmations: task ticked, entry saved.
    static func confirm(reduceMotion: Bool = false) -> Animation {
        reduceMotion ? reduced : .bouncy(duration: 0.4, extraBounce: 0.1)
    }

    /// The Reduce Motion substitute: short, no overshoot.
    /// Toasts slide in and out on a light spring (owner review, Batch B).
    static func toast(reduceMotion: Bool = false) -> Animation {
        reduceMotion ? reduced : .spring(duration: 0.45, bounce: 0.25)
    }

    static let reduced: Animation = .easeOut(duration: 0.2)

    /// Delay between items in a staggered list (SPEC §3.6: 30 ms).
    static let staggerStep: Duration = .milliseconds(30)

    /// Rise distance for staggered rows (SPEC §3.6: 20 pt).
    static let staggerRise: Double = 20

    /// A transition that moves under normal motion and only fades under Reduce Motion.
    static func transition(_ base: AnyTransition, reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : base
    }
}
