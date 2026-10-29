import AVFoundation
import Speech

/// Microphone capture for dictation. The engine's tap runs on the audio thread, converts
/// each buffer to the analyzer's format and hands it on with a level for the waveform.
/// Audio only ever lives in memory: nothing is written to disk (SPEC §8).
nonisolated final class DictationAudioCapture: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?

    enum CaptureError: Error { case noInput, converterUnavailable }

    func start(converting format: AVAudioFormat,
               onInput: @escaping @Sendable (AnalyzerInput) -> Void,
               onLevel: @escaping @Sendable (Float) -> Void) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0 else { throw CaptureError.noInput }
        guard let converter = AVAudioConverter(from: inputFormat, to: format) else { throw CaptureError.converterUnavailable }
        self.converter = converter

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, _ in
            if let channel = buffer.floatChannelData?[0] {
                onLevel(DictationRules.level(of: UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength))))
            }
            if let converted = Self.convert(buffer, with: converter, to: format) {
                onInput(AnalyzerInput(buffer: converted))
            }
        }
        engine.prepare()
        try engine.start()
    }

    func pause() { engine.pause() }

    func resume() throws { try engine.start() }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        converter = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private static func convert(_ buffer: AVAudioPCMBuffer, with converter: AVAudioConverter,
                                to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 16
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        // The converter calls back synchronously on this thread. Older SDKs don't mark the
        // buffer Sendable, so it travels in a box rather than being captured directly.
        let source = BufferBox(buffer: buffer)
        nonisolated(unsafe) var supplied = false
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, inputStatus in
            if supplied {
                inputStatus.pointee = .noDataNow
                return nil
            }
            supplied = true
            inputStatus.pointee = .haveData
            return source.buffer
        }
        guard status != .error, error == nil, output.frameLength > 0 else { return nil }
        return output
    }

    private struct BufferBox: @unchecked Sendable {
        let buffer: AVAudioPCMBuffer
    }
}
