import AuthenticationServices
import SwiftUI

/// The three sign-in buttons (SPEC §6.1 step 5, §6.9 guest Account card), styled to Apple's
/// and Google's brand rules: Apple first, the system button, black in light mode and white
/// in dark; Google white (dark grey in dark mode) with the official "G" and a 1 pt outline.
///
/// Sign-in is wired in Phase 10. Until then each button shows "Available after Phase 10";
/// Release builds don't show these buttons at all (`FeatureFlags.showsSignIn`).
struct SyncSignInButtons: View {
    @Environment(ToastCenter.self) private var toasts
    @Environment(\.colorScheme) private var colorScheme

    static let height: Double = 50

    var body: some View {
        VStack(spacing: Spacing.s) {
            appleButton
            googleButton
            Button(action: notYet) {
                Label("Continue with email", systemImage: "envelope")
                    .font(.system(size: 17, weight: .medium))
                    .frame(maxWidth: .infinity, minHeight: Self.height)
            }
            .buttonStyle(.glass)
            .foregroundStyle(.ink)
        }
    }

    private var appleButton: some View {
        SignInWithAppleButton(.continue) { _ in } onCompletion: { _ in }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: Self.height)
            .clipShape(.capsule)
            // Until Phase 10 the system button only shows; this layer takes the tap.
            .allowsHitTesting(false)
            .overlay {
                Button(action: notYet) { Color.clear.contentShape(.capsule) }
                    .accessibilityLabel("Continue with Apple")
            }
    }

    private var googleButton: some View {
        let dark = colorScheme == .dark
        return Button(action: notYet) {
            HStack(spacing: Spacing.s) {
                Image(.googleMark)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
                Text("Continue with Google")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(dark ? Color(red: 0.89, green: 0.89, blue: 0.89) : Color(red: 0.12, green: 0.12, blue: 0.12))
            }
            .frame(maxWidth: .infinity, minHeight: Self.height)
            .background(dark ? Color(red: 0.075, green: 0.075, blue: 0.08) : .white, in: .capsule)
            .overlay {
                Capsule().strokeBorder(dark ? Color(red: 0.56, green: 0.57, blue: 0.56) : Color(red: 0.45, green: 0.47, blue: 0.46),
                                       lineWidth: 1)
            }
        }
        .buttonStyle(.pressable)
    }

    private func notYet() {
        toasts.show(ToastMessage(text: "Available after Phase 10", systemImage: "clock"))
    }
}

/// "By continuing you agree to the Terms and Privacy Policy" (SPEC §6.1).
struct LegalFooter: View {
    var body: some View {
        Text("By continuing you agree to the [Terms](https://folio.devilsense.com/terms) and [Privacy Policy](https://folio.devilsense.com/privacy).")
            .font(.footnote)
            .foregroundStyle(.inkTertiary)
            .tint(.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.center)
    }
}
