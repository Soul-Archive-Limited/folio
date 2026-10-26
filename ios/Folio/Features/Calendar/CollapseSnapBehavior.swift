import SwiftUI

/// Snaps the day panel's scroll so the grid ends either fully open or fully collapsed —
/// never stuck half-way — while leaving normal scrolling past that point alone.
/// Uses the system's projected target, so a flick carries its momentum (apple-design §6).
nonisolated struct CollapseSnapBehavior: ScrollTargetBehavior {
    let distance: Double
    /// The top content margin that makes room for the grid. At rest the offset is `-topInset`.
    let topInset: Double

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        let progress = target.rect.origin.y + topInset
        guard distance > 0, progress > 0, progress < distance else { return }
        target.rect.origin.y = (progress < distance / 2 ? 0 : distance) - topInset
    }
}
