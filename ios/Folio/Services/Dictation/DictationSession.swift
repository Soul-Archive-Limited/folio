import AVFoundation
import os
import Speech

/// One dictation session (SPEC §6.11, §8): `SpeechAnalyzer` with a `DictationTranscriber`,
/// fully on device. Volatile words are shown dimmed; each final phrase is handed to
/// `onCommit`, which inserts it at the cursor. Only one session runs at a time.
@Observable
final class DictationSession {
    enum State: Equatable {
        case idle
        case preparing
        /// Downloading the on-device speech model, 0…1.
        case downloading(Double)
        case listening
        case paused
        case unavailable(String)
    }

    private(set) var state: State = .idle
    private(set) var volatileText = ""
    private(set) var lastCommitted = ""
    /// Recent mic levels, newest last, for the waveform.
    private(set) var levels: [Float] = Array(repeating: 0, count: 28)

    @ObservationIgnored var onCommit: ((String) -> Void)?
    @ObservationIgnored private var capture: DictationAudioCapture?
    @ObservationIgnored private var analyzer: SpeechAnalyzer?
    @ObservationIgnored private var input: AsyncStream<AnalyzerInput>.Continuation?
    @ObservationIgnored private var resultsTask: Task<Void, Never>?
    @ObservationIgnored private var watchdog: Task<Void, Never>?
    @ObservationIgnored private var lastTap: ContinuousClock.Instant?
    @ObservationIgnored private var startedAt: ContinuousClock.Instant?
    @ObservationIgnored private var lastSpeech: ContinuousClock.Instant?

    /// The session currently using the microphone, so starting another stops it first.
    @ObservationIgnored private static weak var active: DictationSession?
    private static let logger = Logger(subsystem: "com.devilsense.folio", category: "dictation")

    var isRunning: Bool {
        switch state {
        case .preparing, .downloading, .listening, .paused: true
        default: false
        }
    }

    /// Ignores repeat taps within 600 ms (SPEC §8).
    func acceptsTap(at now: ContinuousClock.Instant = .now) -> Bool {
        defer { lastTap = now }
        guard let lastTap else { return true }
        return now - lastTap >= DictationRules.repeatTapWindow
    }

    func start(locale preferred: Locale) async {
        guard !isRunning else { return }
        if let other = Self.active, other !== self { await other.finish() }
        Self.active = self
        state = .preparing
        do {
            guard let locale = await DictationTranscriber.supportedLocale(equivalentTo: preferred) else {
                state = .unavailable(String(localized: "Dictation isn't available in this language yet. You can use the keyboard's mic instead."))
                return
            }
            let transcriber = DictationTranscriber(locale: locale, preset: .progressiveLongDictation)
            try await installAssets(for: transcriber)
            guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
                state = .unavailable(String(localized: "Dictation couldn't start on this iPhone."))
                return
            }
            let (stream, continuation) = AsyncStream.makeStream(of: AnalyzerInput.self)
            input = continuation
            let analyzer = SpeechAnalyzer(modules: [transcriber])
            self.analyzer = analyzer
            resultsTask = Task { [weak self] in
                do {
                    for try await result in transcriber.results {
                        self?.handle(String(result.text.characters), isFinal: result.isFinal)
                    }
                } catch {
                    Self.logger.error("Dictation results ended: \(String(describing: type(of: error)), privacy: .public)")
                }
            }
            try await analyzer.start(inputSequence: stream)

            let capture = DictationAudioCapture()
            self.capture = capture
            try capture.start(converting: format, onInput: { continuation.yield($0) }, onLevel: { [weak self] level in
                Task { @MainActor in self?.record(level) }
            })
            startedAt = .now
            lastSpeech = .now
            state = .listening
            startWatchdog()
        } catch {
            Self.logger.error("Dictation failed to start: \(String(describing: type(of: error)), privacy: .public)")
            await tearDown()
            state = .unavailable(String(localized: "Dictation couldn't start. Try again in a moment."))
        }
    }

    func togglePause() {
        switch state {
        case .listening:
            capture?.pause()
            state = .paused
        case .paused:
            do {
                try capture?.resume()
                lastSpeech = .now
                state = .listening
            } catch {
                Task { await finish() }
            }
        default: break
        }
    }

    /// Done: finalizes what was heard, commits it, and releases the mic.
    func finish() async {
        guard isRunning || analyzer != nil else { return }
        capture?.stop()
        input?.finish()
        do { try await analyzer?.finalizeAndFinishThroughEndOfInput() } catch {
            await analyzer?.cancelAndFinishNow()
        }
        await resultsTask?.value
        await tearDown()
        state = .idle
    }

    /// Leaves without committing what's still volatile (the sheet closed).
    func cancel() async {
        await tearDown()
        state = .idle
    }

    // MARK: Private

    private func installAssets(for transcriber: DictationTranscriber) async throws {
        guard let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) else { return }
        state = .downloading(0)
        let progress = request.progress
        let observer = Task { [weak self] in
            while !Task.isCancelled {
                self?.state = .downloading(progress.fractionCompleted)
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
        defer { observer.cancel() }
        try await request.downloadAndInstall()
        state = .preparing
    }

    private func handle(_ text: String, isFinal: Bool) {
        if isFinal {
            volatileText = ""
            let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { return }
            lastCommitted = clean
            onCommit?(clean)
        } else {
            volatileText = text
        }
        lastSpeech = .now
    }

    private func record(_ level: Float) {
        guard state == .listening else { return }
        levels.removeFirst()
        levels.append(level)
        if level > DictationRules.silenceLevel { lastSpeech = .now }
    }

    private func startWatchdog() {
        watchdog = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, let startedAt = self.startedAt, let lastSpeech = self.lastSpeech else { return }
                let now = ContinuousClock.now
                let silence = self.state == .paused ? .zero : now - lastSpeech
                if DictationRules.shouldStop(silentFor: silence, runningFor: now - startedAt) {
                    await self.finish()
                    return
                }
            }
        }
    }

    private func tearDown() async {
        watchdog?.cancel()
        watchdog = nil
        capture?.stop()
        capture = nil
        input?.finish()
        input = nil
        if let analyzer { await analyzer.cancelAndFinishNow() }
        analyzer = nil
        resultsTask?.cancel()
        resultsTask = nil
        volatileText = ""
        levels = Array(repeating: 0, count: levels.count)
        if Self.active === self { Self.active = nil }
    }

    #if DEBUG
    /// DEBUG-only scripted session for screenshots (`-FolioDemo dictation`): no microphone,
    /// the same states and text the capsule shows when someone speaks.
    func startDemo(words: [String] = ["Walked", "along", "the", "river", "after", "work", "and", "the", "herons", "were", "back"]) {
        state = .listening
        Task { [weak self] in
            var heard: [String] = []
            for word in words {
                try? await Task.sleep(for: .milliseconds(260))
                guard let self, self.state == .listening else { return }
                heard.append(word)
                self.volatileText = heard.joined(separator: " ")
                self.levels.removeFirst()
                self.levels.append(Float.random(in: 0.25...0.9))
                if heard.count == 6 {
                    self.handle(heard.joined(separator: " ") + ",", isFinal: true)
                    heard = []
                }
            }
        }
    }
    #endif
}
