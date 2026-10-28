import AuthenticationServices
import Foundation

/// Profile → Account (SPEC §6.9): who's signed in, devices, sign out, delete account.
extension AccountModel {
    func refreshMe() async {
        guard var stored = session else { return }
        do throws(APIError) {
            let me: AccountAPI.Me = try await api.send("GET", "account/me")
            stored.email = me.email
            stored.providers = me.providers
            updateStoredSession(stored)
        } catch .unauthorized {
            sessionEnded()
        } catch {
            // Offline: the cached details stay.
        }
    }

    func devices() async throws(APIError) -> [AccountAPI.Device] {
        let response: AccountAPI.Devices = try await api.send("GET", "account/devices")
        return response.devices
    }

    func signOutDevice(_ id: String) async throws(APIError) {
        let _: OKResponse = try await api.send("DELETE", "account/devices/\(id)")
    }

    func signOutOtherDevices() async throws(APIError) {
        let _: OKResponse = try await api.send("POST", "account/devices/sign-out-others")
    }

    /// Sign out on this device (SPEC §10.5): stop sync, forget the session and the in-memory key.
    /// The Data Key stays in iCloud Keychain — deleting a synchronizable item would sign the
    /// person's other devices out of their diary too (DECISIONS 182).
    func signOut(keepLocalData: Bool, store: DiaryStore) async {
        if session != nil {
            let _: OKResponse? = try? await api.send("POST", "auth/sign-out")
        }
        finishSignOut(keepLocalData: keepLocalData, store: store)
    }

    /// Delete account (SPEC §10.6). Needs a re-authentication on this session within 10 minutes.
    func deleteAccount(keepLocalData: Bool, store: DiaryStore) async throws(APIError) {
        guard let userID else { return }
        let _: OKResponse = try await api.send("POST", "account/delete", json: AccountAPI.DeleteAccount())
        // The account is gone, so its keys go from every device's iCloud Keychain too.
        Keychain.delete(.dataKey(userID: userID))
        Keychain.delete(.recoveryKey(userID: userID))
        finishSignOut(keepLocalData: keepLocalData, store: store)
    }

    var reauthIsFresh: Bool {
        guard let reauthenticatedAt else { return false }
        return Date.now.timeIntervalSince(reauthenticatedAt) < 9 * 60
    }

    /// The server no longer knows this session (signed out from another device, or the
    /// account was deleted elsewhere). Local data stays, as a guest.
    func sessionEnded() {
        guard isSignedIn, let store = sync?.store else { return }
        finishSignOut(keepLocalData: true, store: store)
        sync?.toasts?.show(ToastMessage(text: "Signed out. Your diary is still on this iPhone.", systemImage: "person.crop.circle.badge.xmark"))
    }

    /// Sign in with Apple can be revoked in Settings; check on launch (authentication skill).
    func checkAppleCredential() async {
        guard let appleUserID = session?.appleUserID else { return }
        let state = try? await ASAuthorizationAppleIDProvider().credentialState(forUserID: appleUserID)
        if state == .revoked { sessionEnded() }
    }

    private func finishSignOut(keepLocalData: Bool, store: DiaryStore) {
        let userID = userID
        sync?.stop()
        StoredSession.remove()
        api.setToken(nil)
        resetToGuest()
        if let userID { SyncState.clear(for: userID) }
        if keepLocalData {
            store.detachFromAccount()
        } else {
            store.eraseAll()
        }
    }
}
