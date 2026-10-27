import SwiftUI

/// First launch (SPEC §6.1, steps 1–5): three welcome pages with parallax, the name step and
/// the sync choice. Skip jumps from the welcome pages to the name step. No permission
/// prompts here. Finishing hands over to the greeting, then the tour (step 8).
struct OnboardingView: View {
    let onFinish: () -> Void

    @Environment(DiaryStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page: OnboardingPage? = .kept
    @State private var name = ""
    @State private var toasts = ToastCenter()
    @State private var lastMove = Date.distantPast
    @State private var proxy: ScrollViewProxy?
    @FocusState private var nameFocused: Bool
    @State private var keyboardShown = false

    var body: some View {
        ScrollViewReader { reader in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(OnboardingPage.allCases) { item in
                        pageView(item)
                            .containerRelativeFrame([.horizontal, .vertical])
                            .id(item)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $page)
            .onAppear { proxy = reader }
            // Swiping away from the name page counts too. (The keyboard's own resize can
            // report the position again, so only a real move off the page dismisses.)
            .onChange(of: page) { _, new in if let new, new != .name { nameFocused = false } }
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .background { AuraBackground() }
        .overlay(alignment: .topTrailing) { skipButton }
        .overlay(alignment: .bottom) { OnboardingPageDots(current: page ?? .kept) }
        // At the top: at the bottom it would cover the sign-in buttons and the legal footer.
        .overlay(alignment: .top) {
            ToastSlot(center: toasts, edge: .top)
                .padding(.horizontal, Spacing.sideMargin)
                .padding(.top, Spacing.xs)
        }
        .environment(toasts)
        .onAppear(perform: applyDebugPage)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in keyboardShown = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidHideNotification)) { _ in keyboardShown = false }
    }

    @ViewBuilder
    private func pageView(_ item: OnboardingPage) -> some View {
        switch item {
        case .kept, .anyDay, .privacy:
            OnboardingWelcomePage(page: item, isCurrent: page == item) { go(to: item.next) }
        case .name:
            OnboardingNameStep(name: $name, focused: $nameFocused,
                               onContinue: { go(to: .sync) }, onSkip: { name = ""; go(to: .sync) })
        case .sync:
            OnboardingSyncStep(onGuest: finish)
        }
    }

    @ViewBuilder
    private var skipButton: some View {
        if let page, page.isWelcome {
            Button("Skip") { go(to: .name) }
                .buttonStyle(.glass)
                .padding(.trailing, Spacing.sideMargin)
                .padding(.top, Spacing.xs)
                .transition(.opacity)
                .accessibilityHint("Skips to choosing your name")
        }
    }

    /// A second tap while the pager is still moving would leave the dots and the page out
    /// of step, so taps within 0.5 s of the last move are ignored.
    private func go(to next: OnboardingPage?) {
        guard let next, Date.now.timeIntervalSince(lastMove) > 0.5 else { return }
        lastMove = .now
        // The keyboard goes first, so it never rides along to the next page. Its height
        // change resizes the pages, which would cancel a scroll started at the same moment,
        // so the pager moves once the keyboard is down.
        nameFocused = false
        Task {
            for _ in 0..<12 where keyboardShown { try? await Task.sleep(for: .milliseconds(50)) }
            // `scrollTo` rather than setting the position binding: on a lazy stack the
            // binding alone doesn't always move the pager.
            withAnimation(reduceMotion ? FolioMotion.reduced : .smooth(duration: 0.45)) {
                proxy?.scrollTo(next, anchor: .leading)
                page = next
            }
        }
    }

    private func finish() {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty { store.updateSettings { $0.displayName = String(clean.prefix(40)) } }
        onFinish()
    }

    private func applyDebugPage() {
        #if DEBUG
        if let raw = DebugLaunchOptions.string("FolioOnboardingPage"), let index = Int(raw),
           OnboardingPage.allCases.indices.contains(index) {
            page = OnboardingPage.allCases[index]
        }
        #endif
    }
}

enum OnboardingPage: Int, CaseIterable, Identifiable, Hashable {
    case kept, anyDay, privacy, name, sync

    var id: Int { rawValue }
    var isWelcome: Bool { self == .kept || self == .anyDay || self == .privacy }
    var next: OnboardingPage? { OnboardingPage(rawValue: rawValue + 1) }
}

/// Page dots; decorative for VoiceOver, which reads each page's own heading instead.
struct OnboardingPageDots: View {
    let current: OnboardingPage

    /// Pages run under the home indicator; their buttons stop this far from the bottom so
    /// the dots sit below them.
    static let clearance: Double = 84

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(OnboardingPage.allCases) { page in
                Capsule()
                    .fill(page == current ? Color.ember : Color.inkTertiary.opacity(0.5))
                    .frame(width: page == current ? 18 : 7, height: 7)
            }
        }
        .animation(.snappy, value: current)
        .padding(.bottom, Spacing.s)
        .accessibilityElement()
        .accessibilityLabel("Page \(current.rawValue + 1) of \(OnboardingPage.allCases.count)")
    }
}

#if DEBUG
#Preview {
    OnboardingView {}
        .environment(PreviewData.previewStore())
}
#endif
