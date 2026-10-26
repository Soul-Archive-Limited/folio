import SwiftUI

/// Shows `PrivacyCoverView` instantly on `.inactive`/`.background` and fades it out over
/// 0.2 s on `.active`. Apply at the window root **and** at the root of every sheet or
/// full-screen cover: SwiftUI presents sheets above the root view's overlays.
struct PrivacyCoverModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(PreferenceKeys.privacyCoverEnabled) private var isEnabled = true
    @Environment(DiaryStore.self) private var store: DiaryStore?

    func body(content: Content) -> some View {
        content.overlay {
            PrivacyCoverView(name: isCovered ? store?.settings().displayName ?? "" : "")
                .opacity(isCovered ? 1 : 0)
                .allowsHitTesting(isCovered)
                .accessibilityHidden(!isCovered)
                .animation(isCovered ? nil : .easeOut(duration: 0.2), value: isCovered)
        }
    }

    private var isCovered: Bool {
        isEnabled && scenePhase != .active
    }
}

extension View {
    func privacyCovered() -> some View {
        modifier(PrivacyCoverModifier())
    }
}
