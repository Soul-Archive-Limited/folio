import Foundation

/// What can go wrong talking to the Folio API (SPEC §10). Never carries tokens or content.
nonisolated enum APIError: Error, Equatable, Sendable {
    /// No connection, timeout or DNS failure: try again later.
    case offline
    /// The session is gone (signed out elsewhere, expired or the account was deleted).
    case unauthorized
    /// 429 or 503 with an optional `Retry-After` in seconds.
    case rateLimited(retryAfter: TimeInterval?)
    /// Any other non-2xx answer, with the API's `{"error": code}` when present.
    case server(status: Int, code: String?)
    /// A 2xx answer the app couldn't read.
    case invalidResponse

    var code: String? {
        if case .server(_, let code) = self { code } else { nil }
    }

    /// Worth retrying with backoff, as opposed to a request the server will always refuse.
    var isTransient: Bool {
        switch self {
        case .offline, .rateLimited: true
        case .server(let status, _): status >= 500
        case .unauthorized, .invalidResponse: false
        }
    }
}
