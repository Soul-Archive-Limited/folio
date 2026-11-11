import SwiftUI

/// Step 3: "What will you keep here?" Pick any; each makes a matching category.
struct OnboardingUsesStep: View {
    let onContinue: () -> Void

    @Environment(OnboardingModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Two columns; one at accessibility sizes, where two split words letter by letter.
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: Spacing.s), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2)
    }

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
                                .foregroundStyle(isOn ? AnyShapeStyle(.white) : AnyShapeStyle(.accent))
                                .frame(width: 28)
                            Text(use.title)
                                .folioFont(.headline)
                                .foregroundStyle(isOn ? AnyShapeStyle(.white) : AnyShapeStyle(.ink))
                                // Batch O: on a 375-pt iPhone "Memories" was hyphenated mid-word;
                                // one line that shrinks a little reads better (wraps at AX sizes).
                                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                                .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.75)
                            Spacer(minLength: 0)
                        }
                        .padding(.leading, Spacing.m)
                        .padding(.trailing, Spacing.s)
                        .frame(minHeight: 60)
                        .background {
                            RoundedRectangle(cornerRadius: Radius.card).fill(.accentStrong).opacity(isOn ? 1 : 0)
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
