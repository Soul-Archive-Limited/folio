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
                    .foregroundStyle(.emberText)
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
                            Capsule().fill(.ember).frame(width: proxy.size.width * progress)
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
                    Button(step.isLast ? "Done" : "Next", action: tour.next)
                        .buttonStyle(.glassProminent)
                        .tint(.emberStrong)
                }
            }
        }
        .padding(Spacing.m)
        .frame(maxWidth: 400)
        .folioGlass(in: .rect(cornerRadius: Radius.card))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tour.card")
        .task(id: step) {
            progress = 0
            guard tour.autoAdvances, !reduceMotion else { return }
            withAnimation(.linear(duration: 4)) { progress = 1 }
        }
    }
}
