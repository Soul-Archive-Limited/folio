import SwiftUI

/// The greeting shown on cold launch (SPEC §4.2). Starts identical to the launch screen,
/// so there's no visible seam between the two.
struct GreetingIntroView: View {
    let model: GreetingIntroModel
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var containerSize: CGSize = .zero

    var body: some View {
        ZStack {
            GreetingBackdrop(stage: model.stage)
                .opacity(isDissolving ? 0 : 1)
            AppMark()
                .scaleEffect(markScale)
                .offset(markOffset)
                .opacity(isDissolving ? 0 : 1)
                .overlay(alignment: .top) {
                    GreetingTextBlock(model: model)
                        .containerRelativeFrame(.horizontal) { width, _ in width - Spacing.sideMargin * 2 }
                        .offset(y: textOffset)
                        .opacity(isDissolving ? 0 : 1)
                        .blur(radius: isDissolving && !reduceMotion ? 6 : 0)
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .onGeometryChange(for: CGSize.self) { $0.size } action: { containerSize = $0 }
        .contentShape(.rect)
        .onTapGesture(perform: model.skip)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Double-tap to skip")
        .accessibilityAction { model.skip() }
        .task { model.start(reduceMotion: reduceMotion, onFinish: onFinish) }
    }

    private var isDissolving: Bool { model.stage >= .dissolving }

    private var markScale: Double {
        guard !reduceMotion else { return 1 }
        if isDissolving { return 56.0 / 72.0 }
        return model.stage >= .lifted ? 0.85 : 1
    }

    /// The mark lifts 60 pt, then travels toward the "+" button as the greeting dissolves.
    private var markOffset: CGSize {
        guard !reduceMotion else { return .zero }
        if isDissolving {
            return CGSize(width: containerSize.width / 2 - FloatingButtonMetrics.centerInsetTrailing,
                          height: containerSize.height / 2 - FloatingButtonMetrics.centerInsetBottom)
        }
        return CGSize(width: 0, height: model.stage >= .lifted ? -60 : 0)
    }

    /// Text sits just under the mark (measured from the mark's unmoved top edge, where the
    /// overlay is anchored); it rises a little as it dissolves.
    private var textOffset: Double {
        guard !reduceMotion else { return 72 + Spacing.l }
        let liftedMarkBottom = 36 - 60 + 36 * 0.85
        let base = liftedMarkBottom + Spacing.l
        return isDissolving ? base - 24 : base
    }
}

#Preview("Morning, with summary") {
    GreetingIntroView(
        model: GreetingIntroModel(
            greeting: "Good morning, Sam.",
            summary: GreetingSummary(tasksToday: 3, pagesThisWeek: 2),
            quietLine: Greetings.quietSummaries[0]
        ),
        onFinish: {}
    )
}
