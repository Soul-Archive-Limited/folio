import Foundation
import FoundationModels
import Observation
import os

/// The ✦ writing tools (SPEC §6.12, §9) on Apple's on-device model: `SystemLanguageModel
/// .default` only, never Private Cloud Compute or any cloud model. Nothing is applied
/// without the user accepting a preview.
@Observable
final class WritingAssistant {
    enum Availability: Equatable {
        case available
        case unavailable(Reason)

        enum Reason: Equatable {
            case deviceNotEligible, appleIntelligenceOff, modelNotReady, language
        }
    }

    enum AssistantError: Error, Equatable {
        case tooSoon, busy, contextTooLong, guardrail, language, unavailable, other

        var message: String {
            switch self {
            case .tooSoon, .busy: String(localized: "One moment — still working on the last request.")
            case .contextTooLong: String(localized: "This entry is too long for writing tools. Try a shorter part.")
            case .guardrail: String(localized: "Apple's model couldn't help with this entry.")
            case .language: String(localized: "Writing tools don't support this language yet.")
            case .unavailable: String(localized: "Writing tools aren't available right now.")
            case .other: String(localized: "That didn't work. Try again.")
            }
        }
    }

    private(set) var isWorking = false
    @ObservationIgnored private var gate = RequestGate()
    @ObservationIgnored private var current: Task<Void, Never>?
    private static let logger = Logger(subsystem: "com.devilsense.folio", category: "intelligence")

    static let instructions = """
    You help someone edit their own private diary. Never add facts, names, places, events, \
    feelings or opinions that aren't in the text. Never change what the writer meant. Keep \
    their voice and their words wherever you can. Always reply in the same language as the \
    diary entry. Keep any Markdown markers (**, *, ~~, ==, #, -, 1.) exactly as they are.
    """

    var availability: Availability {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: PreferenceKeys.fakeIntelligenceUnavailable) {
            return .unavailable(.appleIntelligenceOff)
        }
        if DemoOutput.isOn { return .available }
        #endif
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return model.supportsLocale(Locale.current) ? .available : .unavailable(.language)
        case .unavailable(.deviceNotEligible): return .unavailable(.deviceNotEligible)
        case .unavailable(.appleIntelligenceNotEnabled): return .unavailable(.appleIntelligenceOff)
        case .unavailable: return .unavailable(.modelNotReady)
        }
    }

    // MARK: Tools

    func suggestTitles(for text: String) async throws(AssistantError) -> [String] {
        let result: TitleSuggestions = try await run(
            "Suggest three short titles (2 to 6 words each) for this diary entry. Use only what the entry says.", text)
        return Array(result.titles.map { $0.trimmingCharacters(in: .whitespacesAndNewlines.union(.init(charactersIn: "\"“”"))) }
            .filter { !$0.isEmpty }.prefix(3))
    }

    func polish(_ text: String) async throws(AssistantError) -> String {
        let result: PolishedEntry = try await run(
            "Fix spelling, grammar and punctuation in this diary entry. Change as little as possible. Keep the writer's words.", text)
        return result.text
    }

    func findTasks(in text: String) async throws(AssistantError) -> [String] {
        let result: FoundTasks = try await run(
            "List the things the writer says they need or plan to do, as short to-do items. If there are none, return an empty list.", text)
        return result.tasks.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    func cancel() {
        current?.cancel()
        current = nil
        isWorking = false
    }

    // MARK: Private

    /// One request at a time, at least 1.5 s apart; a new request cancels the previous one.
    private func run<Output: Generable & Sendable>(_ task: String, _ text: String) async throws(AssistantError) -> Output {
        #if DEBUG
        if let demo: Output = await DemoOutput.value() { return demo }
        #endif
        guard availability == .available else { throw .unavailable }
        guard gate.allows(at: .now) else { throw .tooSoon }
        current?.cancel()
        isWorking = true
        defer { isWorking = false }
        let session = LanguageModelSession(model: SystemLanguageModel.default, instructions: Self.instructions)
        let prompt = "\(task)\n\nDiary entry:\n\(RequestGate.clip(text))"
        do {
            let response = try await session.respond(to: prompt, generating: Output.self,
                                                     options: GenerationOptions(temperature: 0.3))
            return response.content
        } catch let error as LanguageModelSession.GenerationError {
            Self.logger.error("Generation failed: \(String(describing: error), privacy: .public)")
            switch error {
            case .exceededContextWindowSize: throw .contextTooLong
            case .guardrailViolation, .refusal: throw .guardrail
            case .unsupportedLanguageOrLocale: throw .language
            case .rateLimited, .concurrentRequests: throw .busy
            case .assetsUnavailable: throw .unavailable
            default: throw .other
            }
        } catch {
            // Error domains and codes only, never content.
            let nsError = error as NSError
            Self.logger.error("Generation failed: \(nsError.domain, privacy: .public) \(nsError.code, privacy: .public)")
            throw .other
        }
    }
}

@Generable
nonisolated struct TitleSuggestions: Sendable {
    @Guide(description: "Three different short titles, 2 to 6 words, no quotation marks", .count(3))
    var titles: [String]
}

@Generable
nonisolated struct PolishedEntry: Sendable {
    @Guide(description: "The whole entry with only spelling, grammar and punctuation fixed")
    var text: String
}

@Generable
nonisolated struct FoundTasks: Sendable {
    @Guide(description: "Short to-do items found in the entry, written as actions", .maximumCount(8))
    var tasks: [String]
}

#if DEBUG
/// DEBUG-only canned results for screenshots (`-FolioDemo intelligence`), for simulators
/// whose host model can't run. Never compiled into Release.
enum DemoOutput {
    static var isOn: Bool { DebugLaunchOptions.string("FolioDemo") == "intelligence" }

    static func value<Output>() async -> Output? {
        guard isOn else { return nil }
        try? await Task.sleep(for: .milliseconds(700))
        let value: Any? = switch Output.self {
        case is TitleSuggestions.Type: TitleSuggestions(titles: ["Cold water, perfect light", "An early swim", "Morning at the lido"])
        case is PolishedEntry.Type: PolishedEntry(text: "The water was colder than I'd expected, but the light was **perfect**.")
        case is FoundTasks.Type: FoundTasks(tasks: ["Book the dentist", "Call Mum about Sunday"])
        default: nil
        }
        return value as? Output
    }
}
#endif
