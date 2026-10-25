import SwiftUI

/// Drives the greeting intro timeline (SPEC §4.2):
/// 0.00 s mark · 0.15 s mark lifts, aura in · 0.30 s words type in · 0.60 s summary ·
/// 1.40 s dissolve into the app. A tap at any point jumps straight to the dissolve.
@Observable
final class GreetingIntroModel {
    enum Stage: Int, Comparable {
        case mark, lifted, revealing, summary, dissolving, finished

        static func < (lhs: Stage, rhs: Stage) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    private(set) var stage: Stage = .mark
    private(set) var revealElapsed: Double = 0

    let greeting: String
    let summary: GreetingSummary
    let quietLine: String
    /// DEBUG: stop before the dissolve so screenshots can be taken.
    var holdsBeforeDissolve = false

    @ObservationIgnored private var timeline: Task<Void, Never>?
    @ObservationIgnored private var onFinish: (() -> Void)?
    @ObservationIgnored private var reduceMotion = false

    let styledGreeting: Text
    let wordCount: Int

    init(greeting: String, summary: GreetingSummary, quietLine: String) {
        self.greeting = greeting
        self.summary = summary
        self.quietLine = quietLine
        (styledGreeting, wordCount) = WordRevealRenderer.text(greeting)
    }

    var revealDuration: Double { WordRevealRenderer.totalDuration(wordCount: wordCount) }

    func start(reduceMotion: Bool, onFinish: @escaping () -> Void) {
        guard timeline == nil else { return }
        self.reduceMotion = reduceMotion
        self.onFinish = onFinish
        timeline = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(150))
                self?.advance(to: .lifted)
                try await Task.sleep(for: .milliseconds(150))
                self?.beginReveal()
                try await Task.sleep(for: .milliseconds(300))
                self?.advance(to: .summary)
                guard self?.holdsBeforeDissolve == false else { return }
                try await Task.sleep(for: .milliseconds(800))
                self?.dissolve()
            } catch {
                // Cancelled by skip(); skip() runs the dissolve itself.
            }
        }
    }

    /// Tap to skip: jump to the end state and dissolve now.
    func skip() {
        guard stage < .dissolving else { return }
        timeline?.cancel()
        revealElapsed = revealDuration
        dissolve()
    }

    private func advance(to next: Stage) {
        withAnimation(FolioMotion.standard(reduceMotion: reduceMotion)) { stage = next }
    }

    private func beginReveal() {
        stage = .revealing
        if reduceMotion {
            withAnimation(FolioMotion.reduced) { revealElapsed = revealDuration }
        } else {
            withAnimation(.linear(duration: revealDuration)) { revealElapsed = revealDuration }
        }
    }

    private func dissolve() {
        let animation = reduceMotion ? FolioMotion.reduced : .smooth(duration: 0.45)
        withAnimation(animation) {
            stage = .dissolving
        } completion: { [weak self] in
            self?.stage = .finished
            self?.onFinish?()
        }
    }
}
