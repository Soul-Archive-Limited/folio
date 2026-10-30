import SwiftUI

/// Step 5: light, dark or match the iPhone — applied live — and the season effect.
struct OnboardingLookStep: View {
    let onContinue: () -> Void

    @Environment(DiaryStore.self) private var store
    @AppStorage(SeasonEffectSetting.key) private var seasonEffect: SeasonEffectSetting = .auto
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let current = AppearancePreference(rawValue: store.settings().appearance) ?? .system
        VStack(spacing: Spacing.l) {
            OnboardingHeading(title: "Your look", subtitle: "Light, dark, or whatever your iPhone is doing.")
                .padding(.top, Spacing.m)
            HStack(spacing: Spacing.s) {
                ForEach(AppearancePreference.allCases, id: \.self) { option in
                    Button {
                        store.updateSettings { $0.appearance = option.rawValue }
                    } label: {
                        VStack(spacing: Spacing.xs) {
                            ThemeSwatch(option: option)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16).strokeBorder(.ember, lineWidth: current == option ? 3 : 0)
                                }
                            Text(option.title).folioFont(.callout).foregroundStyle(.ink)
                        }
                    }
                    .buttonStyle(.pressable)
                    .accessibilityAddTraits(current == option ? .isSelected : [])
                }
            }
            .padding(.horizontal, Spacing.sideMargin)
            .sensoryFeedback(.selection, trigger: current)
            Toggle(isOn: Binding(get: { seasonEffect != .off }, set: { seasonEffect = $0 ? .auto : .off })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Season effect").folioFont(.headline).foregroundStyle(.ink)
                    Text(reduceMotion ? "Off while Reduce Motion is on." : "Blossom, rain, leaves or snow — barely there, at the top.")
                        .folioFont(.callout).foregroundStyle(.inkSecondary)
                }
            }
            .tint(.emberStrong)
            .disabled(reduceMotion)
            .padding(Spacing.m)
            .folioGlass(in: .rect(cornerRadius: Radius.card))
            .padding(.horizontal, Spacing.sideMargin)
            Spacer()
            OnboardingPrimaryButton(title: "Continue", action: onContinue)
                .padding(.horizontal, Spacing.xxl)
                .padding(.bottom, Spacing.l)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A tiny drawing of Folio in a theme: page, a row of days, the ember dot.
private struct ThemeSwatch: View {
    let option: AppearancePreference

    var body: some View {
        HStack(spacing: 0) {
            half(dark: option == .dark)
            if option == .system { half(dark: true) }
        }
        .frame(height: 110)
        .clipShape(.rect(cornerRadius: 16))
        .accessibilityHidden(true)
    }

    private func half(dark: Bool) -> some View {
        let bg = dark ? Color(red: 0.04, green: 0.04, blue: 0.05) : Color(red: 0.96, green: 0.95, blue: 0.94)
        let ink = dark ? Color.white.opacity(0.85) : Color.black.opacity(0.75)
        return ZStack(alignment: .topLeading) {
            bg
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 2).fill(ink).frame(width: 30, height: 5)
                HStack(spacing: 3) {
                    ForEach(0..<4, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(i == 2 ? Color(red: 0.94, green: 0.38, blue: 0.16) : ink.opacity(0.18))
                            .frame(width: 9, height: 9)
                    }
                }
                RoundedRectangle(cornerRadius: 2).fill(ink.opacity(0.3)).frame(width: 40, height: 4)
                RoundedRectangle(cornerRadius: 2).fill(ink.opacity(0.3)).frame(width: 28, height: 4)
            }
            .padding(10)
        }
        .frame(maxWidth: .infinity)
    }
}

extension AppearancePreference {
    var title: LocalizedStringKey {
        switch self {
        case .system: "Match iPhone"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}
