import SwiftUI

/// Runs the guided tour (SPEC §6.15, reworked after the owner's iPhone test, Batch E):
/// - a step's card never shows while the previous step's screen or sheet is still moving —
///   the tour hides the card, navigates, waits for the transition, then shows the next one;
/// - every card says where you are ("2 of 6") and has Back, Next and Skip tour;
/// - steps that live on another screen go there by themselves (after the composer step the
///   tour closes the composer and switches to To-do);
/// - look-only steps move on after about 4 s, action steps when the user does the thing.
///   With VoiceOver on, nothing moves on by itself.
@Observable
final class TourModel {
    /// The step the tour is on, nil when it isn't running.
    private(set) var current: TourStep?
    /// The step whose card is on screen. Lags `current` while a transition settles.
    private(set) var visible: TourStep?
    /// Anchor frames in global coordinates, reported by `.tourAnchor(_:)`.
    var anchors: [TourStep: CGRect] = [:]

    /// Whether the open composer has writing in it; the composer reports it. The tour never
    /// closes a composer with writing in it, and its card steps aside while the user types.
    private(set) var composerHasChanges = false

    /// Set by `MainTabView` so the tour can move between screens.
    @ObservationIgnored var navigator: TourNavigator?
    /// Where to go once the user closes a composer the tour couldn't close for them.
    @ObservationIgnored private var afterComposerCloses: TourStep?
    @ObservationIgnored private var pending: Task<Void, Never>?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let settle: Duration

    static let autoAdvanceDelay: Duration = .seconds(4)
    private static let stepKey = "tourStep"

    init(defaults: UserDefaults = .standard, settle: Duration = .milliseconds(550)) {
        self.defaults = defaults
        self.settle = settle
    }

    var isRunning: Bool { current != nil }

    /// Whether `visible` should move on by itself (look-only, and VoiceOver is off).
    var autoAdvances: Bool {
        guard let visible else { return false }
        return visible.isLookOnly && !UIAccessibility.isVoiceOverRunning && !(visible == .composerTools && composerHasChanges)
    }

    // MARK: Starting and stopping

    /// After onboarding and its greeting.
    func start() { go(to: .month) }

    /// Profile → Help → "Show the tour again".
    func replay() { go(to: .month) }

    /// Picks up a tour the app was closed in the middle of, at that step's screen. Inside the
    /// composer it restarts from "+" instead, since the composer isn't open after a launch.
    func resumeIfNeeded() {
        guard current == nil, let step = TourStep(rawValue: defaults.integer(forKey: Self.stepKey)) else { return }
        go(to: step == .composerTools ? .add : step)
    }

    func skip() { stop() }

    private func stop() {
        pending?.cancel()
        afterComposerCloses = nil
        current = nil
        visible = nil
        defaults.removeObject(forKey: Self.stepKey)
    }

    // MARK: Buttons

    func next() {
        guard let current else { return }
        if let step = current.next { go(to: step) } else { stop() }
    }

    func back() {
        guard let step = current?.previous else { return }
        go(to: step)
    }

    // MARK: Things the user does

    func didSelectDay() {
        if current == .tapDay { next() }
    }

    /// The composer opened. On "+" that's the step done; the tools card shows once the sheet
    /// has finished rising.
    func didOpenComposer() {
        guard current == .add else { return }
        show(.composerTools, after: settle)
    }

    /// The user closed the composer themselves while its card was up (Save or Cancel).
    func didCloseComposer() {
        composerHasChanges = false
        guard current == .composerTools else { return }
        let step = afterComposerCloses ?? .todo
        afterComposerCloses = nil
        go(to: step)
    }

    /// Typing in the composer hides its card; closing the composer carries on to To-do.
    func composerChanged(hasChanges: Bool) {
        composerHasChanges = hasChanges
        if hasChanges, visible == .composerTools { visible = nil }
    }

    // MARK: Moving

    /// Hides the card, moves to the step's screen, waits for the transition, then shows it.
    func go(to step: TourStep) {
        let from = current
        visible = nil
        current = step
        defaults.set(step.rawValue, forKey: Self.stepKey)
        var moved = false
        if let navigator {
            if step == .composerTools {
                if !navigator.isComposerOpen() { navigator.openComposer(); moved = true }
            } else if navigator.isComposerOpen() {
                // Only an empty composer is closed for the user; one with writing in it waits
                // for them to save or cancel (didCloseComposer carries on from there).
                guard !composerHasChanges else {
                    current = .composerTools
                    afterComposerCloses = step
                    return
                }
                navigator.closeComposer()
                moved = true
            }
            if navigator.selectedTab() != step.tab {
                navigator.select(step.tab)
                moved = true
            }
        }
        show(step, after: moved || from == nil ? settle : .zero)
    }

    private func show(_ step: TourStep, after delay: Duration) {
        pending?.cancel()
        visible = nil
        current = step
        defaults.set(step.rawValue, forKey: Self.stepKey)
        pending = Task { [weak self] in
            if delay > .zero { try? await Task.sleep(for: delay) }
            // Wait (briefly) for the step's anchor to be laid out on its screen.
            for _ in 0..<20 where self?.hasAnchor(for: step) == false {
                try? await Task.sleep(for: .milliseconds(50))
            }
            guard let self, !Task.isCancelled, self.current == step else { return }
            self.visible = step
            await self.autoAdvance(from: step)
        }
    }

    private func hasAnchor(for step: TourStep) -> Bool {
        step == .todo || step == .profile || anchors[step] != nil
    }

    private func autoAdvance(from step: TourStep) async {
        guard autoAdvances else { return }
        try? await Task.sleep(for: Self.autoAdvanceDelay)
        guard !Task.isCancelled, visible == step, autoAdvances else { return }
        next()
    }

    // MARK: Setup

    /// DEBUG `-FolioTourStep N` starts the tour at step N; UI tests pass
    /// `-com.apple.TipKit.HideAllTips 1` (kept from the TipKit tour) or `-FolioNoTour YES` to
    /// keep it away.
    static func configure(defaults: UserDefaults = .standard) {
        #if DEBUG
        if defaults.bool(forKey: "com.apple.TipKit.HideAllTips") || defaults.bool(forKey: "FolioNoTour") {
            defaults.removeObject(forKey: stepKey)
        }
        let step = defaults.integer(forKey: "FolioTourStep")
        if TourStep(rawValue: step) != nil { defaults.set(step, forKey: stepKey) }
        #endif
    }
}

/// What the tour may do to the app's navigation; supplied by `MainTabView`.
struct TourNavigator {
    let selectedTab: () -> AppTab
    let select: (AppTab) -> Void
    let isComposerOpen: () -> Bool
    let openComposer: () -> Void
    let closeComposer: () -> Void
}
