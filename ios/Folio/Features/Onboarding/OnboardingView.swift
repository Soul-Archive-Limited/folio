import SwiftUI

/// First launch (SPEC §6.1, redesigned in Batch I — docs/ONBOARDING.md): welcome → your first
/// line on today → what you'll keep → name and picture → look → sync, then the greeting and the
/// tour. A `NavigationStack`, not a pager: going back is the system's interactive back swipe,
/// which can't come to rest between two steps (the old pager resized under the keyboard
/// mid-swipe and stuck half-way). No permission prompts here.
struct OnboardingView: View {
    let onFinish: () -> Void

    @Environment(DiaryStore.self) private var store
    @State private var model = OnboardingModel()
    @State private var toasts = ToastCenter()

    var body: some View {
        NavigationStack(path: $model.path) {
            OnboardingWelcomeStep { model.go(to: .firstLine) }
                .navigationDestination(for: OnboardingStep.self) { step in
                    stepView(step)
                        // Steps never resize for the keyboard, so nothing jumps under a swipe;
                        // fields sit high enough to stay above it.
                        .ignoresSafeArea(.keyboard)
                        .toolbar {
                            ToolbarItem(placement: .principal) { OnboardingProgress(step: step) }
                        }
                        .navigationBarTitleDisplayMode(.inline)
                        .background { AuraBackground() }
                }
                .background { AuraBackground() }
                .toolbarVisibility(.hidden, for: .navigationBar)
        }
        // Steps never resize for the keyboard, so nothing jumps under a swipe.
        .ignoresSafeArea(.keyboard)
        .overlay(alignment: .top) {
            ToastSlot(center: toasts, edge: .top)
                .padding(.horizontal, Spacing.sideMargin)
                .padding(.top, Spacing.xs)
        }
        .environment(toasts)
        .environment(model)
        .onChange(of: model.path) { KeyboardDismissal.dismiss() }
        .onAppear(perform: applyDebugStep)
    }

    @ViewBuilder
    private func stepView(_ step: OnboardingStep) -> some View {
        switch step {
        case .welcome: EmptyView()
        case .firstLine: OnboardingFirstLineStep { model.go(to: .uses) }
        case .uses: OnboardingUsesStep { model.go(to: .you) }
        case .you: OnboardingYouStep { model.go(to: .look) }
        case .look: OnboardingLookStep { model.go(to: .sync) }
        case .sync: OnboardingSyncStep(onGuest: finish)
        }
    }

    private func finish() {
        model.apply(to: store)
        onFinish()
    }

    private func applyDebugStep() {
        #if DEBUG
        if let raw = DebugLaunchOptions.string("FolioOnboardingPage"), let index = Int(raw),
           let step = OnboardingStep(rawValue: index), step != .welcome {
            model.path = OnboardingStep.allCases.filter { $0 != .welcome && $0.rawValue <= index }
        }
        #endif
    }
}

#if DEBUG
#Preview {
    OnboardingView {}
        .environment(PreviewData.previewStore())
}
#endif
