import Foundation

/// A sign-in or account error in plain words (SPEC §6.14: errors say what to do next).
enum SignInProblem: Equatable {
    case offline, tooMany, wrongCode, deleting, reauthMismatch, failed

    var message: LocalizedStringResource {
        switch self {
        case .offline: "You're offline. Check your connection and try again."
        case .tooMany: "Too many tries. Wait a few minutes, then try again."
        case .wrongCode: "That code didn't work. Check it, or send a new one."
        case .deleting: "This account is being deleted. Try again in a few minutes."
        case .reauthMismatch: "That's a different account. Sign in with the one you use here."
        case .failed: "Sign-in didn't work. Please try again."
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
        default: .failed
        }
    }
}
