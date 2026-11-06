import Foundation

/// A sign-in or account error in plain words (SPEC §6.14: errors say what to do next).
enum SignInProblem: Equatable {
    case offline, tooMany, wrongCode, deleting, reauthMismatch, failed
    /// Batch K: the Google round trip came back with a reason.
    case expired, googleUnavailable
    /// Batch J: a new account needs an invite code.
    case inviteRequired, inviteInvalid

    var needsInvite: Bool { self == .inviteRequired || self == .inviteInvalid }

    var message: LocalizedStringResource {
        switch self {
        case .offline: "You're offline. Check your connection and try again."
        case .tooMany: "Too many tries. Wait a few minutes, then try again."
        case .wrongCode: "That code didn't work. Check it, or send a new one."
        case .deleting: "This account is being deleted. Try again in a few minutes."
        case .reauthMismatch: "That's a different account. Sign in with the one you use here."
        case .failed: "Sign-in didn't work. Please try again."
        case .expired: "That sign-in took too long and expired. Please try again."
        case .googleUnavailable: "Google sign-in isn't working on our side right now. Please use Apple or email, or try again later."
        case .inviteRequired: "Folio is invite-only for now. Enter the invite code you were given."
        case .inviteInvalid: "That invite code didn't work. It may be used, expired or mistyped."
        }
    }
}

extension SignInProblem {
    /// The `error` the Worker puts on `folio://auth?error=…` (Batch K).
    init(oauthError: String?) {
        self = switch oauthError {
        case "invite_required": .inviteRequired
        case "invite_invalid": .inviteInvalid
        case "expired": .expired
        case "google_unavailable": .googleUnavailable
        case "account_deleting": .deleting
        default: .failed
        }
    }
}

extension APIError {
    var signInProblem: SignInProblem {
        switch self {
        case .offline: .offline
        case .rateLimited: .tooMany
        case .server(_, "invalid_code"): .wrongCode
        case .server(409, _): .deleting
        case .server(_, "reauth_mismatch"): .reauthMismatch
        case .server(403, "invite_required"): .inviteRequired
        case .server(403, "invite_invalid"): .inviteInvalid
        default: .failed
        }
    }
}
