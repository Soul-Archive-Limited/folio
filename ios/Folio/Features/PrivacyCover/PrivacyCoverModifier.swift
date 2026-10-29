import SwiftUI

/// Shows `PrivacyCoverView` instantly on `.inactive`/`.background` and fades it out over
/// 0.2 s on `.active`. Apply at the window root **and** at the root of every sheet or
/// full-screen cover: SwiftUI presents sheets above the root view's overlays.
struct PrivacyCoverModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(PreferenceKeys.privacyCoverEnabled) private var isEnabled = true
    @Environment(DiaryStore.self) private var store: DiaryStore?
    /// A cold launch passes through `.inactive` before the first `.active`; covering then
    /// would flash over the launch greeting. Only cover after the app has been on screen.
    @State private var hasBeenActive = false

    func body(content: Content) -> some View {
        content.overlay {
            // Only in the view tree while covering: an invisible copy was still found by
            // accessibility audits (Phase 14). Appears instantly, fades out over 0.2 s.
            ZStack {
                if isCovered {
                    PrivacyCoverView(name: store?.settings().displayName ?? "")
                        .transition(.opacity)
                }
            }
            .animation(isCovered ? nil : .easeOut(duration: 0.2), value: isCovered)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active { hasBeenActive = true }
        }
    }

    private var isCovered: Bool {
        isEnabled && hasBeenActive && scenePhase != .active
    }
}

extension View {
    func privacyCovered() -> some View {
        modifier(PrivacyCoverModifier())
    }
}
