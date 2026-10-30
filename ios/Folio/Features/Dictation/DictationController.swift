import AVFoundation
import Speech
import SwiftUI

/// Runs the microphone flow for a composer (SPEC §7, §8): one explainer before the first
/// system prompt, covering both prompts iOS shows (microphone, then speech recognition —
/// confirmed on the owner's iPhone, Batch E), a gentle "Open Settings" path when either is
/// off, then the session.
@Observable
final class DictationController {
    let session = DictationSession()
    var showsExplainer = false
    var showsDenied = false
    /// Whether dictation exists for the chosen language; the mic is hidden when it doesn't.
    private(set) var isSupported = true
    /// Words to expect (name, categories, title), set by the composer before starting.
    var hints: () -> [String] = { [] }

    static var preferredLocale: Locale {
        let identifier = UserDefaults.standard.string(forKey: PreferenceKeys.dictationLocale) ?? ""
        return identifier.isEmpty ? DictationRules.regionalLocale(for: .current) : Locale(identifier: identifier)
    }

    func checkSupport() async {
        isSupported = await DictationTranscriber.supportedLocale(equivalentTo: Self.preferredLocale) != nil
    }

    /// Mic tap: starts, or finishes a running session. Repeat taps within 600 ms are ignored.
    func micTapped() {
        guard session.acceptsTap() else { return }
        #if DEBUG
        if DebugLaunchOptions.string("FolioDemo") == "dictation", !session.isRunning { return session.startDemo() }
        #endif
        if session.isRunning {
            Task { await session.finish() }
            return
        }
        switch DictationAccess.current {
        case .granted: Task { await session.start(locale: Self.preferredLocale, hints: hints()) }
        case .needsPrompt: showsExplainer = true
        case .denied: showsDenied = true
        }
    }

    /// Continue on the explainer: both system prompts, back to back, then the session.
    func requestAccess() {
        showsExplainer = false
        Task {
            if await DictationAccess.request() {
                await session.start(locale: Self.preferredLocale, hints: hints())
            } else {
                showsDenied = true
            }
        }
    }

    var isVisible: Bool { session.state != .idle }
}

extension View {
    /// The explainer and denied alert for the mic, attached once per composer.
    func dictationPermissions(_ controller: DictationController) -> some View {
        modifier(DictationPermissionsModifier(controller: controller))
    }
}

private struct DictationPermissionsModifier: ViewModifier {
    @Bindable var controller: DictationController
    @Environment(\.openURL) private var openURL

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $controller.showsExplainer) {
                PermissionExplainer(
                    systemImage: "mic",
                    message: "Dictation needs the microphone and speech recognition. Both are processed on your iPhone — your voice is never stored or sent anywhere.",
                    footnote: "iOS will ask for each one next.",
                    onContinue: controller.requestAccess
                )
            }
            .alert("Dictation is off for Folio", isPresented: $controller.showsDenied) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                Button("Not now", role: .cancel) {}
            } message: {
                Text("Turn on Microphone and Speech Recognition in Settings whenever you'd like to dictate entries.")
            }
    }
}
