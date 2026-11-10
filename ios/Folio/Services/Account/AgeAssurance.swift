@preconcurrency import DeclaredAgeRange
import Foundation
import Synchronization

/// Batch M: Apple's age check, where the law requires one (Texas SB 2420 and similar state
/// app-store laws; `docs/COMPLIANCE.md` §5). Folio accounts are for adults (SPEC §10.2b); guest
/// mode sends nothing and stays open to everyone, so only signing in is checked.
///
/// - **Where it's required** (`requiredRegulatoryFeatures` contains `.declaredAgeRangeRequired`;
///   `isEligibleForAgeFeatures` before iOS 26.4): ticking "I'm 18 or older" asks Apple for the
///   age range with an 18 gate. Under 18 → no account; Apple couldn't answer → try again.
/// - **Elsewhere:** nothing is asked; the self-declared box is the rule, as before.
/// - If iOS can't tell whether it's required (an error), Folio doesn't ask: the box still applies.
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

    /// Whether the law where this person is requires the check. iOS has to answer within
    /// `timeout`: on the iOS 26.5 Simulator `requiredRegulatoryFeatures` never returns, and a
    /// hang there would leave the 18+ box untickable. No answer in time counts as "can't tell".
    @concurrent nonisolated static func isRequired(timeout: Duration = .seconds(3)) async -> Bool {
        #if DEBUG
        if simulatedAnswer != nil { return true }
        #endif
        let answered = Mutex(false)
        return await withCheckedContinuation { continuation in
            // Unstructured on purpose: a task group would wait for a call that never returns.
            Task { @concurrent in
                let required = await regionRequiresCheck()
                if answered.withLock({ done in defer { done = true }; return !done }) { continuation.resume(returning: required) }
            }
            Task { @concurrent in
                try? await Task.sleep(for: timeout)
                if answered.withLock({ done in defer { done = true }; return !done }) { continuation.resume(returning: false) }
            }
        }
    }

    /// Off the main actor: Apple's service isn't `Sendable`, and its getters are nonisolated.
    @concurrent nonisolated private static func regionRequiresCheck() async -> Bool {
        guard #available(iOS 26.2, *) else { return false }
        if #available(iOS 26.4, *), let features = try? await AgeRangeService.shared.requiredRegulatoryFeatures {
            return features.contains(.declaredAgeRangeRequired)
        }
        return (try? await AgeRangeService.shared.isEligibleForAgeFeatures) ?? false
    }

    /// Asks Apple (the system shows its own sheet the first time) and decides.
    @MainActor
    static func check(with request: DeclaredAgeRangeAction) async -> Decision {
        #if DEBUG
        if let simulatedAnswer { return decide(simulatedAnswer) }
        #endif
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
