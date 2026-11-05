import LocalAuthentication
import os
import SwiftUI
import UIKit

/// Lock Folio (Batch J): Face ID / Touch ID / passcode before the diary shows.
///
/// The lock lives in its own window above everything in every scene — sheets, alerts, menus —
/// so nothing the app was showing can appear before an unlock, whatever opened it (a deep
/// link, a widget, a shortcut). Whenever the app goes to the background with the lock on, the
/// window goes up at once as a cover (so the app-switcher snapshot is the cover too); coming
/// back within "Lock after" fades it away, otherwise it asks for Face ID.
@Observable
final class AppLock {
    static let shared = AppLock()

    enum State: Equatable {
        /// Nothing over the app.
        case open
        /// The cover is up while the app is away; no prompt.
        case covered
        /// Needs Face ID / passcode.
        case locked
    }

    private(set) var state: State
    private(set) var isAuthenticating = false
    /// "Face ID", "Touch ID", "Optic ID" or "Passcode", for the button.
    private(set) var methodName = String(localized: "Passcode")
    private(set) var methodSymbol = "lock.fill"
    /// Set when the last attempt failed for a reason worth saying (not a cancel).
    private(set) var problem: String?
    /// The person's name for the lock screen's greeting; the root view keeps it current.
    var displayName = ""

    @ObservationIgnored private var windows: [ObjectIdentifier: UIWindow] = [:]
    @ObservationIgnored private var leftAt: Date?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let logger = Logger(subsystem: "com.devilsense.folio", category: "lock")

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        state = defaults.bool(forKey: PreferenceKeys.lockEnabled) ? .locked : .open
        refreshMethod()
    }

    var isEnabled: Bool { defaults.bool(forKey: PreferenceKeys.lockEnabled) }
    var lockAfter: LockAfter { LockAfter(rawValue: defaults.integer(forKey: PreferenceKeys.lockAfter)) ?? .immediately }
    /// The app's own views draw only once the lock window is up (cold launch).
    var hidesContent: Bool { state != .open && windows.isEmpty }

    // MARK: Scene phases

    func didEnterBackground(now: Date = AppClock.now) {
        guard isEnabled else { return }
        leftAt = now
        if state == .open { state = .covered }
        showWindows()
    }

    func didBecomeActive(now: Date = AppClock.now) {
        // Returning from the Face ID sheet makes the app active again: not a new visit.
        guard !isAuthenticating else { return }
        guard isEnabled else {
            if state != .open { open() }
            return
        }
        switch state {
        case .open:
            return
        case .covered:
            guard lockAfter.requiresUnlock(leftAt: leftAt, now: now) else { open(); return }
            state = .locked
        case .locked:
            break
        }
        showWindows()
        Task { await unlock() }
    }

    /// A new scene (iPad window) or the first one at launch.
    func attachScenes() {
        if state != .open { showWindows() }
    }

    // MARK: Unlock

    func unlock() async {
        guard state == .locked, !isAuthenticating else { return }
        #if DEBUG
        if defaults.bool(forKey: "FolioSkipOwnerAuth") { open(); return }
        #endif
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // The passcode was turned off since: iOS no longer protects anything, so neither
            // can we. Open, and say so in Profile.
            logger.notice("Lock: device owner authentication unavailable; opening")
            open()
            return
        }
        isAuthenticating = true
        problem = nil
        defer { isAuthenticating = false }
        do {
            if try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: String(localized: "Unlock your diary")) {
                open()
            }
        } catch let error as LAError where error.code == .userCancel || error.code == .appCancel || error.code == .systemCancel {
            // Stay locked; the button is there.
        } catch {
            problem = String(localized: "Couldn't unlock. Try again.")
        }
    }

    // MARK: Settings

    /// Turning the lock on or off asks for Face ID / passcode first, so it's really the owner.
    func setEnabled(_ enabled: Bool) async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            problem = String(localized: "Set a passcode in the Settings app to lock Folio.")
            return false
        }
        #if DEBUG
        if defaults.bool(forKey: "FolioSkipOwnerAuth") { defaults.set(enabled, forKey: PreferenceKeys.lockEnabled); return true }
        #endif
        isAuthenticating = true
        defer { isAuthenticating = false }
        let reason = enabled ? String(localized: "Lock Folio with Face ID or your passcode") : String(localized: "Turn off the lock")
        guard (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) == true else { return false }
        defaults.set(enabled, forKey: PreferenceKeys.lockEnabled)
        problem = nil
        return true
    }

    var canUseLock: Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    // MARK: Windows

    private func open() {
        state = .open
        problem = nil
        hideWindows()
    }

    private func refreshMethod() {
        let context = LAContext()
        var error: NSError?
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        switch context.biometryType {
        case .faceID: (methodName, methodSymbol) = (String(localized: "Face ID"), "faceid")
        case .touchID: (methodName, methodSymbol) = (String(localized: "Touch ID"), "touchid")
        case .opticID: (methodName, methodSymbol) = (String(localized: "Optic ID"), "opticid")
        default: (methodName, methodSymbol) = (String(localized: "Passcode"), "lock.fill")
        }
    }

    private func showWindows() {
        refreshMethod()
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes where windows[ObjectIdentifier(scene)] == nil {
            let window = UIWindow(windowScene: scene)
            // Above alerts and menus; the keyboard is put away when it locks.
            window.windowLevel = .alert + 1
            let host = UIHostingController(rootView: LockScreenView(lock: self))
            host.view.backgroundColor = .clear
            window.rootViewController = host
            window.overrideUserInterfaceStyle = scene.windows.first?.overrideUserInterfaceStyle ?? .unspecified
            window.makeKeyAndVisible()
            windows[ObjectIdentifier(scene)] = window
        }
        if state == .locked {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    private func hideWindows() {
        let closing = windows.values
        windows = [:]
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseOut]) {
            closing.forEach { $0.alpha = 0 }
        } completion: { _ in
            closing.forEach {
                $0.isHidden = true
                $0.windowScene?.windows.first { $0.windowLevel == .normal }?.makeKey()
            }
        }
    }
}
