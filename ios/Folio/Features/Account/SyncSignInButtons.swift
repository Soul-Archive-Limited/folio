import AuthenticationServices
import SwiftUI

/// The three sign-in buttons (SPEC §6.1 step 5, §6.9 guest Account card, §10.6 re-auth),
/// styled to Apple's and Google's brand rules: Apple first, the system button, black in light
/// mode and white in dark; Google white (dark grey in dark mode) with the official "G" and a
/// 1 pt outline. Apple and Google finish here; email asks the parent to show its steps.
struct SyncSignInButtons: View {
    /// Re-authenticate the current session (delete account) instead of signing in.
    var reauth = false
    let onEmail: () -> Void
    /// Apple or Google finished (signed in, or re-authenticated).
    var onDone: () -> Void = {}

    @Environment(AccountModel.self) private var account
    @Environment(ToastCenter.self) private var toasts
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession
    @State private var rawNonce = ""
    @State private var busy = false
    @State private var signedIn = 0
    /// Batch J: Apple or Google said this would be a new account and needs an invite.
    @State private var invitePrompt: InvitePrompt?
    @State private var appleRunner = AppleSignInRunner()
    @State private var nudge = false

    private var needsConsent: Bool { !reauth && !account.ageConfirmed }

    private func askForConsent() {
        withAnimation(FolioMotion.standard()) { nudge = true }
        AccessibilityNotification.Announcement("Tick “I’m 18 or older” first. Folio accounts are for adults.").post()
    }

    struct InvitePrompt: Identifiable {
        enum Provider { case apple, google }
        let id = UUID()
        let provider: Provider
        let problem: SignInProblem
    }

    static let height: Double = 50

    var body: some View {
        VStack(spacing: Spacing.s) {
            if !reauth { consentRow }
            // Batch L: the buttons stay tappable; before the box is ticked a tap points at it and
            // says why (spoken too), instead of a silent disabled state.
            providerButtons
                .opacity(needsConsent ? 0.55 : 1)
            if nudge && needsConsent { consentNudge }
        }
        .disabled(busy)
        .opacity(busy ? 0.6 : 1)
        .overlay { if busy { ProgressView().controlSize(.large) } }
        .folioHaptic(.success, trigger: signedIn)
        .sheet(item: $invitePrompt) { prompt in
            InviteCodeSheet(problem: prompt.problem) { code in
                switch prompt.provider {
                case .google: google(invite: code)
                case .apple: appleWithInvite(code)
                }
            }
        }
    }

    private var consentRow: some View {
        @Bindable var account = account
        return AgeConsentRow(isOn: $account.ageConfirmed, needsAttention: nudge)
    }

    private var providerButtons: some View {
        VStack(spacing: Spacing.s) {
            appleButton.overlay { if needsConsent { appleConsentCatcher } }
            googleButton
            emailButton
        }
    }

    /// Over Apple's system button (which can't be told "not yet"): the tap and VoiceOver
    /// activation ask for the box first.
    private var appleConsentCatcher: some View {
        Capsule().fill(.clear).contentShape(.capsule)
            .onTapGesture(perform: askForConsent)
            .accessibilityElement()
            .accessibilityLabel(Text("Continue with Apple"))
            .accessibilityHint(Text("Tick “I’m 18 or older” above first."))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default) { askForConsent() }
    }

    private var consentNudge: some View {
        Text("Tick the box to continue. Folio accounts are for adults.")
            .font(.footnote.weight(.medium))
            .foregroundStyle(.danger)
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.opacity)
    }

    private var emailButton: some View {
            Button { if needsConsent { askForConsent() } else { onEmail() } } label: {
                Label("Continue with email", systemImage: "envelope")
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity, minHeight: Self.height)
            }
            .buttonStyle(.glass)
            .foregroundStyle(.ink)
    }

    private var appleButton: some View {
        SignInWithAppleButton(.continue) { request in
            rawNonce = SignInSecrets.randomToken()
            request.requestedScopes = reauth ? [] : [.email]
            request.nonce = SignInSecrets.sha256Hex(rawNonce)
        } onCompletion: { result in
            switch result {
            case .success(let authorization):
                guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
                run(provider: .apple) { () throws(APIError) in try await account.signInWithApple(credential, rawNonce: rawNonce, reauth: reauth) }
            case .failure(let error):
                if (error as? ASAuthorizationError)?.code != .canceled { show(.failed) }
            }
        }
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        // The system button reads its style once; rebuild it when the appearance changes.
        .id(colorScheme)
        .frame(height: Self.height)
        .clipShape(.capsule)
    }

    private var googleButton: some View {
        let dark = colorScheme == .dark
        return Button { if needsConsent { askForConsent() } else { google() } } label: {
            HStack(spacing: Spacing.s) {
                Image(.googleMark)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
                Text("Continue with Google")
                    .font(.body.weight(.medium))
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

    private func google(invite: String? = nil) {
        busy = true
        Task {
            defer { busy = false }
            do throws(GoogleSignInError) {
                try await account.signInWithGoogle(using: webAuthenticationSession, reauth: reauth, invite: invite)
                finished()
            } catch .cancelled {
            } catch .refused(let problem) {
                handle(problem, provider: .google)
            } catch .api(let error) {
                handle(error.signInProblem, provider: .google)
            } catch {
                show(.failed)
            }
        }
    }

    /// Sign in with Apple again, this time with the invite.
    private func appleWithInvite(_ invite: String) {
        let nonce = SignInSecrets.randomToken()
        Task {
            guard let credential = await appleRunner.run(nonceHash: SignInSecrets.sha256Hex(nonce)) else { return }
            run(provider: .apple) { () throws(APIError) in
                try await account.signInWithApple(credential, rawNonce: nonce, reauth: reauth, invite: invite)
            }
        }
    }

    private func run(provider: InvitePrompt.Provider, _ work: @escaping () async throws(APIError) -> Void) {
        busy = true
        Task {
            defer { busy = false }
            do throws(APIError) {
                try await work()
                finished()
            } catch {
                handle(error.signInProblem, provider: provider)
            }
        }
    }

    private func handle(_ problem: SignInProblem, provider: InvitePrompt.Provider) {
        if problem.needsInvite { invitePrompt = InvitePrompt(provider: provider, problem: problem) } else { show(problem) }
    }

    private func finished() {
        signedIn += 1
        onDone()
    }

    private func show(_ problem: SignInProblem) {
        toasts.show(ToastMessage(text: problem.message, systemImage: "exclamationmark.triangle.fill"))
    }
}

/// Batch L: accounts are 18+. An unticked box above the sign-in buttons; they wait for it. A real
/// `Toggle` (VoiceOver announces it as a switch with its state), with the Terms and Privacy Policy
/// as their own links underneath so they can be opened on their own (independent review).
struct AgeConsentRow: View {
    @Binding var isOn: Bool
    var needsAttention = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Toggle("I’m 18 or older and agree to the Terms and Privacy Policy", isOn: $isOn)
                .toggleStyle(CheckboxToggleStyle())
                .accessibilityHint("Required to create an account.")
            HStack(spacing: Spacing.m) {
                Link("Read the Terms", destination: URL(string: "https://folio.devilsense.com/terms")!)
                    .frame(minWidth: Spacing.minHitTarget, minHeight: Spacing.minHitTarget).contentShape(.rect)
                Link("Privacy Policy", destination: URL(string: "https://folio.devilsense.com/privacy")!)
                    .frame(minWidth: Spacing.minHitTarget, minHeight: Spacing.minHitTarget).contentShape(.rect)
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(.accentText)
            .frame(minHeight: Spacing.minHitTarget)
            .padding(.leading, 34)
        }
        .padding(Spacing.s)
        .overlay {
            RoundedRectangle(cornerRadius: Radius.dayCell, style: .continuous)
                .strokeBorder(.danger, lineWidth: needsAttention && !isOn ? 1.5 : 0)
        }
    }
}

/// A square checkbox for the consent toggle; the whole row toggles it (≥ 44 pt tall).
private struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(configuration.isOn ? AnyShapeStyle(.accentStrong) : AnyShapeStyle(.inkSecondary))
                    .contentTransition(.symbolEffect(.replace))
                configuration.label
                    .font(.subheadline)
                    .foregroundStyle(.ink)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: Spacing.minHitTarget)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

/// What signing in is for (SPEC §6.1, Batch L): plain purpose text, no marketing.
struct LegalFooter: View {
    var body: some View {
        Text("We use your email to sign you in and for account messages (codes, a deletion confirmation) — never for marketing. Your diary is encrypted so only you can read it.")
            .font(.footnote)
            .foregroundStyle(.inkSecondary)
            .tint(.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.center)
    }
}
