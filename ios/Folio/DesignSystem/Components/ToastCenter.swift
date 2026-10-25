import SwiftUI

/// Shows one toast at a time; a new toast replaces the current one. Toasts stay 4 s
/// (SPEC §6.14), and each is announced to VoiceOver.
@Observable
final class ToastCenter {
    private(set) var current: ToastMessage?
    @ObservationIgnored private var dismissTask: Task<Void, Never>?

    static let displayDuration: Duration = .seconds(4)

    func show(_ message: ToastMessage) {
        current = message
        AccessibilityNotification.Announcement(String(localized: message.text)).post()
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: Self.displayDuration)
            guard !Task.isCancelled else { return }
            self?.dismiss(message.id)
        }
    }

    func dismiss(_ id: ToastMessage.ID? = nil) {
        guard id == nil || current?.id == id else { return }
        current = nil
    }

    func performUndo() {
        guard let undo = current?.undo else { return }
        undo.perform()
        dismiss()
    }
}
