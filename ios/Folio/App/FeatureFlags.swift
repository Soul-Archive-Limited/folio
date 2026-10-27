import Foundation

/// Features that exist in the UI before their backend does. Release builds never show a
/// control that can't work yet (owner, Batch C).
nonisolated enum FeatureFlags {
    /// Apple / Google / email sign-in. Wired in Phase 10; until then DEBUG builds show the
    /// buttons with an "Available after Phase 10" toast and Release builds hide them.
    static var showsSignIn: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }
}
