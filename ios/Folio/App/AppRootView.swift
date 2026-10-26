import SwiftUI

/// The window root: the app, the greeting on cold launch, and the privacy cover.
struct AppRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(DiaryStore.self) private var store
    @State private var greeting: GreetingIntroModel?

    var body: some View {
        ZStack {
            content
            if let greeting {
                GreetingIntroView(model: greeting) { self.greeting = nil }
                    .zIndex(1)
            }
        }
        .privacyCovered()
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                UserDefaults.standard.set(AppClock.now, forKey: PreferenceKeys.lastBackgroundAt)
            }
        }
        .task { prepareGreetingIfNeeded() }
    }

    @ViewBuilder private var content: some View {
        #if DEBUG
        switch DebugLaunchOptions.screen {
        case .gallery: DesignGalleryView()
        case .cover: PrivacyCoverView(name: store.settings().displayName)
        case .greeting, nil: HomePlaceholderView()
        }
        #else
        HomePlaceholderView()
        #endif
    }

    private func prepareGreetingIfNeeded() {
        guard greeting == nil else { return }
        let factory = GreetingFactory(defaults: .standard)
        #if DEBUG
        if let screen = DebugLaunchOptions.screen, screen != .greeting { return }
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
