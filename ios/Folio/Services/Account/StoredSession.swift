import Foundation

/// The signed-in session as kept in the Keychain (this device only, SPEC §10.2).
nonisolated struct StoredSession: Codable, Equatable, Sendable {
    let token: String
    let sessionID: String
    let userID: UUID
    /// The address or provider shown in Profile; filled from `/account/me`.
    var email: String?
    var providers: [String] = []
    /// Sign in with Apple's user id, to check on launch that the person hasn't revoked it.
    var appleUserID: String?

    static func load() -> StoredSession? {
        Keychain.data(for: .session).flatMap { try? JSONDecoder().decode(StoredSession.self, from: $0) }
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        Keychain.set(data, for: .session)
    }

    static func remove() {
        Keychain.delete(.session)
    }
}
