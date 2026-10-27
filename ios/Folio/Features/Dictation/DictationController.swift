import AVFoundation
import Speech
import SwiftUI

/// Runs the microphone flow for a composer (SPEC §7, §8): a one-line explainer before the
/// first system prompt, a gentle "Open Settings" path when access is off, then the session.
@Observable
final class DictationController {
    let session = DictationSession()
    var showsExplainer = false
    var showsDenied = false
    /// Whether dictation exists for the chosen language; the mic is hidden when it doesn't.
    private(set) var isSupported = true

    static var preferredLocale: Locale {
        let identifier = UserDefaults.standard.string(forKey: PreferenceKeys.dictationLocale) ?? ""
        return identifier.isEmpty ? .current : Locale(identifier: identifier)
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
        switch AVAudioApplication.shared.recordPermission {
        case .granted: Task { await session.start(locale: Self.preferredLocale) }
        case .undetermined: showsExplainer = true
        default: showsDenied = true
        }
    }

    func requestAccess() {
        showsExplainer = false
        Task {
            if await AVAudioApplication.requestRecordPermission() {
                await session.start(locale: Self.preferredLocale)
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
                    message: "Folio uses the microphone only while you dictate. Audio is processed on your iPhone and never stored or sent anywhere.",
                    onContinue: controller.requestAccess
                )
            }
            .alert("Microphone is off for Folio", isPresented: $controller.showsDenied) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                Button("Not now", role: .cancel) {}
            } message: {
                Text("You can turn it on in Settings whenever you'd like to dictate entries.")
            }
    }
}
