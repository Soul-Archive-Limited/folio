import SwiftUI

/// The window root: onboarding on first launch, then the app, the greeting on cold launch,
/// the guided tour after onboarding, and the privacy cover.
struct AppRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(DiaryStore.self) private var store
    @AppStorage(PreferenceKeys.hasOnboarded) private var hasOnboarded = false
    @State private var greeting: GreetingIntroModel?
    @State private var tour = TourModel()
    @State private var startsTourAfterGreeting = false

    var body: some View {
        ZStack {
            if hasOnboarded {
                content
            } else {
                OnboardingView(onFinish: finishOnboarding)
                    .transition(.opacity)
            }
            if let greeting {
                GreetingIntroView(model: greeting, onFinish: greetingFinished)
                    .zIndex(1)
            }
        }
        .environment(tour)
        .preferredColorScheme(AppearancePreference(rawValue: store.settings().appearance)?.colorScheme)
        .privacyCovered()
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                UserDefaults.standard.set(AppClock.now, forKey: PreferenceKeys.lastBackgroundAt)
            }
        }
        .task { prepareGreetingIfNeeded() }
        .task(priority: .utility) { await store.backfillDisplayRenditions() }
    }

    @ViewBuilder private var content: some View {
        #if DEBUG
        switch DebugLaunchOptions.screen {
        case .gallery: DesignGalleryView()
        case .cover: PrivacyCoverView(name: store.settings().displayName)
        case .greeting, nil: MainTabView()
        }
        #else
        MainTabView()
        #endif
    }

    /// SPEC §6.1 step 8: onboarding → greeting → tour.
    private func finishOnboarding() {
        withAnimation(.smooth(duration: 0.3)) { hasOnboarded = true }
        startsTourAfterGreeting = true
        greeting = GreetingFactory(defaults: .standard)
            .makeIfNeeded(now: AppClock.now, name: store.settings().displayName, summary: store.greetingSummary(), force: true)
        if greeting == nil { tour.start() }
    }

    private func greetingFinished() {
        greeting = nil
        if startsTourAfterGreeting {
            startsTourAfterGreeting = false
            tour.start()
        }
    }

    private func prepareGreetingIfNeeded() {
        guard greeting == nil, hasOnboarded else { return }
        let factory = GreetingFactory(defaults: .standard)
        #if DEBUG
        if let screen = DebugLaunchOptions.screen, screen != .greeting { return }
        if DebugLaunchOptions.skipsGreeting { return }
        let force = DebugLaunchOptions.screen == .greeting
        #else
        let force = false
        #endif
        greeting = factory.makeIfNeeded(now: AppClock.now, name: store.settings().displayName,
                                        summary: store.greetingSummary(), force: force)
        #if DEBUG
        greeting?.holdsBeforeDissolve = DebugLaunchOptions.holdsGreeting
        #endif
    }
}
