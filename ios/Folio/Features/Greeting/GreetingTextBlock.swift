import SwiftUI

/// The greeting line (typed in word by word) and the summary line beneath it.
struct GreetingTextBlock: View {
    let model: GreetingIntroModel

    var body: some View {
        VStack(spacing: Spacing.s) {
            model.styledGreeting
                .folioFont(.title1)
                .foregroundStyle(.ink)
                .multilineTextAlignment(.center)
                .textRenderer(WordRevealRenderer(elapsed: model.revealElapsed))
                .accessibilityLabel(model.greeting)
            summaryText
                .folioFont(.callout)
                .foregroundStyle(.inkSecondary)
                .multilineTextAlignment(.center)
                .opacity(model.stage >= .summary ? 1 : 0)
                .blur(radius: model.stage >= .summary ? 0 : 4)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var summaryText: Text {
        model.summary.text ?? Text(model.quietLine)
    }
}
