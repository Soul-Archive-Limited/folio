import Foundation
import Testing
@testable import Folio

@Suite("Lock Folio")
struct AppLockTests {
    let left = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("Immediately: any time away locks")
    func immediately() {
        #expect(LockAfter.immediately.requiresUnlock(leftAt: left, now: left))
        #expect(LockAfter.immediately.requiresUnlock(leftAt: left, now: left.addingTimeInterval(1)))
    }

    @Test("Lock after N minutes: coming back sooner doesn't ask")
    func delays() {
        #expect(!LockAfter.oneMinute.requiresUnlock(leftAt: left, now: left.addingTimeInterval(59)))
        #expect(LockAfter.oneMinute.requiresUnlock(leftAt: left, now: left.addingTimeInterval(60)))
        #expect(!LockAfter.fifteenMinutes.requiresUnlock(leftAt: left, now: left.addingTimeInterval(899)))
        #expect(LockAfter.fifteenMinutes.requiresUnlock(leftAt: left, now: left.addingTimeInterval(900)))
    }

    @Test("A clock that went backwards, or no record of leaving, locks")
    func untrustedClock() {
        #expect(LockAfter.fifteenMinutes.requiresUnlock(leftAt: left, now: left.addingTimeInterval(-5)))
        #expect(LockAfter.fifteenMinutes.requiresUnlock(leftAt: nil, now: left))
    }

    @MainActor
    @Test("Starts locked when the lock is on; open when it's off")
    func initialState() throws {
        let defaults = try #require(UserDefaults(suiteName: "lock-test-\(UUID().uuidString)"))
        #expect(AppLock(defaults: defaults).state == .open)
        defaults.set(true, forKey: PreferenceKeys.lockEnabled)
        #expect(AppLock(defaults: defaults).state == .locked)
    }
}
