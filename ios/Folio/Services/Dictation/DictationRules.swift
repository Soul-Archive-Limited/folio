import Foundation

/// The small rules dictation follows (SPEC §8), kept pure so they're testable.
nonisolated enum DictationRules {
    /// Stop after 2 minutes without speech, or 30 minutes in all.
    static let silenceLimit: Duration = .seconds(120)
    static let sessionLimit: Duration = .seconds(30 * 60)
    /// Repeat taps on the mic within this window are ignored.
    static let repeatTapWindow: Duration = .milliseconds(600)
    /// Below this level (0…1) the mic is treated as silence.
    static let silenceLevel: Float = 0.04

    static func shouldStop(silentFor silence: Duration, runningFor total: Duration) -> Bool {
        silence >= silenceLimit || total >= sessionLimit
    }

    /// Text to insert for a committed phrase: a space goes before it unless the cursor is at
    /// the start of a line or already after whitespace, and none before closing punctuation.
    static func insertion(_ phrase: String, after previous: Character?) -> String {
        let trimmed = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        guard let previous, !previous.isWhitespace else { return trimmed }
        if let first = trimmed.first, ".,;:!?)…".contains(first) { return trimmed }
        return " " + trimmed
    }

    /// RMS of float samples, mapped to 0…1 for the waveform.
    static func level(of samples: UnsafeBufferPointer<Float>) -> Float {
        guard !samples.isEmpty else { return 0 }
        var sum: Float = 0
        for sample in samples { sum += sample * sample }
        let rms = (sum / Float(samples.count)).squareRoot()
        // About -50 dB → 0 and -10 dB → 1, which suits speech at arm's length.
        let decibels = 20 * log10(max(rms, 1e-6))
        return min(max((decibels + 50) / 40, 0), 1)
    }
}
