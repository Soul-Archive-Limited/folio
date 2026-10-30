import SwiftUI

/// Step 3: "What will you keep here?" Pick any; each makes a matching category.
struct OnboardingUsesStep: View {
    let onContinue: () -> Void

    @Environment(OnboardingModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let columns = [GridItem(.flexible(), spacing: Spacing.s), GridItem(.flexible(), spacing: Spacing.s)]

    var body: some View {
        VStack(spacing: Spacing.l) {
            OnboardingHeading(title: "What will you keep here?", subtitle: "Pick any. We'll set up categories to match.")
                .padding(.top, Spacing.m)
            LazyVGrid(columns: columns, spacing: Spacing.s) {
                ForEach(OnboardingUse.allCases) { use in
                    let isOn = model.uses.contains(use)
                    Button {
                        withAnimation(FolioMotion.interactive(reduceMotion: reduceMotion)) {
                            if isOn { model.uses.remove(use) } else { model.uses.insert(use) }
                        }
                    } label: {
                        HStack(spacing: Spacing.s) {
                            Image(systemName: use.symbol)
                                .font(.title3)
                                .foregroundStyle(isOn ? AnyShapeStyle(.white) : AnyShapeStyle(.ember))
                                .frame(width: 28)
                            Text(use.title)
                                .folioFont(.headline)
                                .foregroundStyle(isOn ? AnyShapeStyle(.white) : AnyShapeStyle(.ink))
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, Spacing.m)
                        .frame(minHeight: 60)
                        .background {
                            RoundedRectangle(cornerRadius: Radius.card).fill(.emberStrong).opacity(isOn ? 1 : 0)
                        }
                        .folioGlass(in: .rect(cornerRadius: Radius.card), interactive: true)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
            .padding(.horizontal, Spacing.sideMargin)
            .sensoryFeedback(.selection, trigger: model.uses)
            Spacer()
            OnboardingPrimaryButton(title: model.uses.isEmpty ? "Skip" : "Continue", action: onContinue)
                .padding(.horizontal, Spacing.xxl)
                .padding(.bottom, Spacing.l)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
