import SwiftUI

/// Step 4: your name (optional) and your picture — a Folio avatar or the monogram.
struct OnboardingYouStep: View {
    let onContinue: () -> Void

    @Environment(OnboardingModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var model = model
        VStack(spacing: Spacing.l) {
            preview
                .padding(.top, Spacing.m)
            OnboardingHeading(title: "What should we call you?", subtitle: "Only used to greet you. Pick a picture too, if you like.")
            TextField("Your name", text: $model.name)
                .textContentType(.givenName)
                .submitLabel(.continue)
                .focused($focused)
                // Return continues (the keyboard covers the button); focus drops first.
                .onSubmit {
                    focused = false
                    onContinue()
                }
                .accessibilityIdentifier("onboarding.name")
                .folioFont(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.l)
                .frame(minHeight: 52)
                .folioGlass(in: .capsule, interactive: true)
                .contentShape(.capsule)
                .onTapGesture { focused = true }
                .padding(.horizontal, Spacing.xxl)
            avatarRow
            Spacer(minLength: 0)
            OnboardingPrimaryButton(title: "Continue") {
                focused = false
                onContinue()
            }
            .padding(.horizontal, Spacing.xxl)
            .padding(.bottom, Spacing.l)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // A tap outside the field puts the keyboard away; it never follows to the next step.
        .background { Color.clear.contentShape(.rect).onTapGesture { focused = false } }
        .onDisappear { focused = false }
    }

    private var preview: some View {
        Group {
            if let number = FolioAvatar.number(from: model.avatar) {
                Image(FolioAvatar.assetName(number)).resizable().scaledToFit()
            } else {
                Monogram(name: model.name, size: 84)
            }
        }
        .frame(width: 84, height: 84)
        .contentTransition(.opacity)
        .animation(reduceMotion ? FolioMotion.reduced : .bouncy(duration: 0.4, extraBounce: 0.1), value: model.avatar)
        .accessibilityHidden(true)
    }

    private var avatarRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Spacing.s) {
                choice(nil) { Monogram(name: model.name, size: 52) }
                ForEach(1...FolioAvatar.count, id: \.self) { number in
                    choice(FolioAvatar.key(number)) {
                        Image(FolioAvatar.assetName(number)).resizable().scaledToFit()
                    }
                    .accessibilityLabel(Text(FolioAvatar.name(number)))
                }
            }
            .padding(.horizontal, Spacing.sideMargin)
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
        .sensoryFeedback(.selection, trigger: model.avatar)
    }

    private func choice<Content: View>(_ key: String?, @ViewBuilder content: () -> Content) -> some View {
        let isOn = model.avatar == key
        return Button {
            model.avatar = key
        } label: {
            content()
                .frame(width: 52, height: 52)
                .padding(3)
                .overlay { Circle().strokeBorder(.ember, lineWidth: isOn ? 3 : 0) }
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(key == nil ? Text("Monogram") : Text(""))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
