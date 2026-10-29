import AuthenticationServices
import FolioCrypto
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

    /// The person's own name for a device, opened with the Data Key; nil if none (or locked).
    func label(of device: AccountAPI.Device) -> String? {
        guard let sealedText = device.label, let userID, let dataKey, let recordID = UUID(uuidString: device.id),
              let nonce = Data(base64Encoded: sealedText.nonce), let ciphertext = Data(base64Encoded: sealedText.ciphertext),
              let plain = try? RecordCipher.open(SealedRecord(nonce: nonce, ciphertextAndTag: ciphertext),
                                                 recordID: recordID, type: .deviceLabel, userID: userID, using: dataKey) else { return nil }
        return String(data: plain, encoding: .utf8)
    }

    /// Renames any of the person's devices; an empty name goes back to the model name.
    func renameDevice(_ id: String, to name: String) async throws(APIError) {
        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.deviceLabelLimit))
        var sealedText: AccountAPI.SealedText?
        if !trimmed.isEmpty {
            guard let userID, let dataKey, let recordID = UUID(uuidString: id),
                  let sealed = try? RecordCipher.seal(Data(trimmed.utf8), recordID: recordID, type: .deviceLabel, userID: userID, using: dataKey)
            else { throw .invalidResponse }
            sealedText = AccountAPI.SealedText(ciphertext: sealed.ciphertextAndTag.base64EncodedString(), nonce: sealed.nonce.base64EncodedString())
        }
        let _: OKResponse = try await api.send("PUT", "account/devices/\(id)/label", json: AccountAPI.DeviceLabel(label: sealedText))
    }

    static let deviceLabelLimit = 40

    /// Tells the server this device's model and OS once per session and after OS updates, so
    /// Devices reads "iPhone 15 Pro · iOS 27.1" rather than what an older build sent.
    func reportDeviceNameIfNeeded() async {
        guard let sessionID = session?.sessionID else { return }
        let name = DeviceInfo.name
        let marker = "\(sessionID)|\(name)"
        guard UserDefaults.standard.string(forKey: Self.reportedDeviceKey) != marker else { return }
        let sent: OKResponse? = try? await api.send("PUT", "account/device", json: AccountAPI.DeviceName(name: name))
        if sent != nil { UserDefaults.standard.set(marker, forKey: Self.reportedDeviceKey) }
    }

    private static let reportedDeviceKey = "FolioReportedDeviceName"

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
