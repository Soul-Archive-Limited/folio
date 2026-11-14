import Foundation

/// Which Folio account the pages left on this iPhone came from (Batch O, owner's privacy check).
///
/// Signing out with "keep my diary on this iPhone" (or the server ending the session) leaves
/// that account's pages here as a guest diary, marked to upload. Without this, the next sign-in
/// — even to a different person's account — would upload them into that account. Now a
/// different account has to choose first: add them, or remove them from this iPhone. A first-time
/// guest's pages (no origin) and the same account signing back in are unaffected.
enum LocalDiaryOrigin {
    static let defaultsKey = "folio.localDiaryAccount"

    static var accountID: UUID? {
        get { UserDefaults.standard.string(forKey: defaultsKey).flatMap(UUID.init(uuidString:)) }
        set { UserDefaults.standard.set(newValue?.uuidString, forKey: defaultsKey) }
    }

    /// Whether signing in as `userID` must ask before this iPhone's pages join that account.
    static func needsChoice(signingIn userID: UUID, origin: UUID?, hasLocalPages: Bool) -> Bool {
        guard let origin, hasLocalPages else { return false }
        return origin != userID
    }
}
