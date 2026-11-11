import SwiftUI

/// One tour step on glass: "2 of 6", title, message, a thin countdown for steps that move on
/// by themselves, and Back / Next (Done on the last) / Skip tour.
struct TourCard: View {
    let step: TourStep
    let tour: TourModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress = 0.0

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                Text("\(step.rawValue) of \(TourStep.allCases.count)")
                    .folioFont(.caption)
                    .foregroundStyle(.accentText)
                    .accessibilityLabel("Step \(step.rawValue) of \(TourStep.allCases.count)")
                    .accessibilityIdentifier("tour.count")
                Spacer()
                Button("Skip tour", action: tour.skip)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.inkSecondary)
                    .frame(minHeight: Spacing.minHitTarget - 8)
            }
            Text(step.title)
                .folioFont(.headline)
                .foregroundStyle(.ink)
                .accessibilityAddTraits(.isHeader)
            Text(step.message)
                .folioFont(.callout)
                .foregroundStyle(.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if tour.autoAdvances {
                Capsule()
                    .fill(.hairline)
                    .frame(height: 3)
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Capsule().fill(.accent).frame(width: proxy.size.width * progress)
                        }
                    }
                    .accessibilityHidden(true)
            }
            GlassEffectContainer(spacing: Spacing.s) {
                HStack(spacing: Spacing.s) {
                    if step.previous != nil {
                        Button("Back", action: tour.back)
                            .buttonStyle(.glass)
                    }
                    Spacer()
                    Button(step.isLast ? "Done" : "Next", action: tour.nextTapped)
                        .buttonStyle(.glassProminent)
                        .tint(.accentStrong)
                }
            }
        }
        .padding(Spacing.m)
        .frame(maxWidth: 400)
        // Batch O (independent review): the clear glass let the screen's text show through the
        // card's words, and taps on the card's padding reached the content underneath (opening
        // an entry mid-tour). A solid surface under the glass, and the whole card takes touches.
        .background(SheetSurface().clipShape(.rect(cornerRadius: Radius.card)))
        .folioGlass(in: .rect(cornerRadius: Radius.card))
        .contentShape(.rect(cornerRadius: Radius.card))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tour.card")
        .task(id: step) {
            progress = 0
            guard tour.autoAdvances, !reduceMotion else { return }
            withAnimation(.linear(duration: 4)) { progress = 1 }
        }
    }
}
