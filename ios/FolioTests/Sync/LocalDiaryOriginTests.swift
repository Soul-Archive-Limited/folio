import Foundation
import Testing
@testable import Folio

/// Batch O: one person's pages left on an iPhone never upload into another person's account.
@Suite("Pages from another account", .serialized)
struct LocalDiaryOriginTests {
    let alice = UUID()
    let bob = UUID()

    @Test("A different account must choose before the pages join it")
    func differentAccountAsks() {
        #expect(LocalDiaryOrigin.needsChoice(signingIn: bob, origin: alice, hasLocalPages: true))
    }

    @Test("The same account signing back in just syncs")
    func sameAccountSyncs() {
        #expect(!LocalDiaryOrigin.needsChoice(signingIn: alice, origin: alice, hasLocalPages: true))
    }

    @Test("A first-time guest's pages join the account they sign in to")
    func guestJoins() {
        #expect(!LocalDiaryOrigin.needsChoice(signingIn: bob, origin: nil, hasLocalPages: true))
    }

    @Test("Nothing on the iPhone: nothing to ask")
    func emptyDoesNotAsk() {
        #expect(!LocalDiaryOrigin.needsChoice(signingIn: bob, origin: alice, hasLocalPages: false))
    }

    @Test("The origin survives a relaunch and can be cleared")
    func persists() {
        let saved = LocalDiaryOrigin.accountID
        defer { LocalDiaryOrigin.accountID = saved }
        LocalDiaryOrigin.accountID = alice
        #expect(LocalDiaryOrigin.accountID == alice)
        LocalDiaryOrigin.accountID = nil
        #expect(LocalDiaryOrigin.accountID == nil)
    }
}
