import AVFoundation
import Speech

/// Dictation needs two permissions, and iOS asks for each separately: the microphone, then
/// speech recognition (SPEC §7). Folio explains both once, then asks for both in a row.
nonisolated enum DictationAccess: Equatable, Sendable {
    case granted
    /// At least one prompt hasn't been shown yet and none was refused.
    case needsPrompt
    /// The microphone or speech recognition is off (or restricted) for Folio.
    case denied

    static var current: DictationAccess {
        resolve(microphone: AVAudioApplication.shared.recordPermission, speech: SFSpeechRecognizer.authorizationStatus())
    }

    static func resolve(microphone: AVAudioApplication.recordPermission,
                        speech: SFSpeechRecognizerAuthorizationStatus) -> DictationAccess {
        let micDenied = microphone == .denied
        let speechDenied = speech == .denied || speech == .restricted
        if micDenied || speechDenied { return .denied }
        if microphone == .granted && speech == .authorized { return .granted }
        return .needsPrompt
    }

    /// Shows whichever system prompts are still due, microphone first.
    static func request() async -> Bool {
        guard await AVAudioApplication.requestRecordPermission() else { return false }
        if SFSpeechRecognizer.authorizationStatus() == .authorized { return true }
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        return status == .authorized
    }
}
