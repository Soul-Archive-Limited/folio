@preconcurrency import DeclaredAgeRange
import Foundation
import Synchronization

/// Batch M: Apple's age check, where the law requires one (Texas SB 2420 and similar state
/// app-store laws; `docs/COMPLIANCE.md` §5). Folio accounts are for adults (SPEC §10.2b); guest
/// mode sends nothing and stays open to everyone, so only signing in is checked.
///
/// - **Where it's required** — iOS says so for this person: `isEligibleForAgeFeatures` (per
///   person: "location and account settings"), and on iOS 26.4+ also `requiredRegulatoryFeatures`
///   containing `.declaredAgeRangeRequired` — ticking "I'm 18 or older" asks Apple for the age
///   range with an 18 gate. Under 18 → no account; Apple couldn't answer → try again.
/// - **Elsewhere:** nothing is asked; the self-declared box is the rule, as before.
/// - If iOS can't tell whether it's required (an error, or no answer in time), Folio doesn't
///   ask: the box still applies.
enum AgeAssurance {
    /// What Apple answered, reduced to what Folio needs.
    enum Answer: Equatable {
        case shared(lowerBound: Int?)
        case declined
        case failed(Failure)
    }

    enum Failure: Equatable {
        /// No network, or Apple's service didn't answer.
        case network
        /// The person (or their Apple Account) didn't set up age sharing.
        case notSetUp
    }

    enum Decision: Equatable {
        case adult
        case notAdult
        case couldNotCheck(Failure)

        /// The sentence shown (and spoken) when the box can't stay ticked.
        var message: String? {
            switch self {
            case .adult: nil
            case .notAdult: "Folio accounts are for adults. You can keep using Folio on this iPhone without an account — your diary stays here."
            case .couldNotCheck(.network): "Apple couldn’t confirm your age just now. Check your connection and try again."
            case .couldNotCheck: "Folio needs your age range from Apple to make an account here. You can keep using Folio without an account."
            }
        }
    }

    static let adultAge = 18

    /// A `lowerBound` of 18 or more is an adult; `nil` means under the lowest gate (18).
    static func decide(_ answer: Answer) -> Decision {
        switch answer {
        case .shared(let lowerBound): (lowerBound ?? 0) >= adultAge ? .adult : .notAdult
        // Where the check is required people can't decline; if it happens anyway, no account.
        case .declined: .couldNotCheck(.notSetUp)
        case .failed(let failure): .couldNotCheck(failure)
        }
    }

    /// Started at launch (`AppRootView`), so the answer is ready long before anyone reaches a
    /// sign-in screen; a new launch asks again (someone may have travelled).
    nonisolated static let requirement = Task { await isRequired() }

    /// Whether the law where this person is requires the check; no answer within `timeout`
    /// counts as "can't tell".
    @concurrent nonisolated static func isRequired(timeout: Duration = .seconds(3)) async -> Bool {
        #if DEBUG
        if simulatedAnswer != nil { return true }
        #endif
        return await first(within: timeout, otherwise: false) { await regionRequiresCheck() }
    }

    /// Both of iOS's signals must agree. On the iOS 26.5 Simulator `requiredRegulatoryFeatures`
    /// lists every duty while `isEligibleForAgeFeatures` is false; Texas applies to new Apple
    /// Accounts only, which only the per-person flag reflects. Off the main actor: Apple's
    /// service isn't `Sendable`, and its getters are nonisolated.
    @concurrent nonisolated private static func regionRequiresCheck() async -> Bool {
        guard #available(iOS 26.2, *), (try? await AgeRangeService.shared.isEligibleForAgeFeatures) == true else { return false }
        if #available(iOS 26.4, *), let features = try? await AgeRangeService.shared.requiredRegulatoryFeatures {
            return features.contains(.declaredAgeRangeRequired)
        }
        return true
    }

    /// Asks Apple (the system shows its own sheet the first time) and decides. Two minutes at
    /// most: once in the Simulator the request never came back, which would have left the box
    /// disabled for good.
    @MainActor
    static func check(with request: DeclaredAgeRangeAction) async -> Decision {
        #if DEBUG
        if let simulatedAnswer { return decide(simulatedAnswer) }
        #endif
        return await first(within: .seconds(120), otherwise: .couldNotCheck(.network)) { @MainActor in await ask(request) }
    }

    @MainActor
    private static func ask(_ request: DeclaredAgeRangeAction) async -> Decision {
        do {
            switch try await request(ageGates: adultAge) {
            case .sharing(let range): return decide(.shared(lowerBound: range.lowerBound))
            case .declinedSharing: return decide(.declined)
            @unknown default: return decide(.declined)
            }
        } catch AgeRangeService.Error.notAvailable {
            return decide(.failed(.notSetUp))
        } catch {
            // `network`, `declinedOnboarding` and `invalidAccount` aren't matched by name: the
            // iOS 27 SDK declares them without availability, and iOS 26 doesn't have them, so
            // naming them stops the app launching there. A retry is the useful advice anyway.
            return decide(.failed(.network))
        }
    }

    /// Whichever comes first: `operation`'s answer or `fallback` after `timeout`. Unstructured
    /// on purpose: a task group would wait for a call that never returns.
    private nonisolated static func first<Value: Sendable>(within timeout: Duration, otherwise fallback: Value,
                                                            _ operation: @escaping @Sendable () async -> Value) async -> Value {
        let once = FirstAnswer()
        return await withCheckedContinuation { continuation in
            Task {
                let value = await operation()
                if once.claim() { continuation.resume(returning: value) }
            }
            Task {
                try? await Task.sleep(for: timeout)
                if once.claim() { continuation.resume(returning: fallback) }
            }
        }
    }

    /// True for the first caller only, so the continuation resumes exactly once.
    private nonisolated final class FirstAnswer: Sendable {
        private let taken = Mutex(false)

        func claim() -> Bool {
            taken.withLock { taken in
                defer { taken = true }
                return !taken
            }
        }
    }

    #if DEBUG
    /// `-FolioAgeCheck adult|minor|network|notSetUp` pretends this is a region that requires the
    /// check and that Apple answered so (the Simulator has no age range to share).
    nonisolated static var simulatedAnswer: Answer? {
        switch UserDefaults.standard.string(forKey: "FolioAgeCheck") {
        case "adult": .shared(lowerBound: 18)
        case "minor": .shared(lowerBound: nil)
        case "network": .failed(.network)
        case "notSetUp": .failed(.notSetUp)
        default: nil
        }
    }
    #endif
}
