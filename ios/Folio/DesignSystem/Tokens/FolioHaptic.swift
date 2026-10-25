import SwiftUI

/// Haptic vocabulary (SPEC §3.7). One haptic per gesture, maximum.
enum FolioHaptic: Sendable {
    /// Day tap, month change.
    case selection
    /// Task complete, entry save, sign-in.
    case success
    /// Untick, chip toggle.
    case lightImpact
    /// Just before a destructive confirmation.
    case warning

    var feedback: SensoryFeedback {
        switch self {
        case .selection: .selection
        case .success: .success
        case .lightImpact: .impact(weight: .light)
        case .warning: .warning
        }
    }
}

extension View {
    /// Plays a Folio haptic whenever `trigger` changes.
    func folioHaptic(_ haptic: FolioHaptic, trigger: some Equatable) -> some View {
        sensoryFeedback(haptic.feedback, trigger: trigger)
    }
}
