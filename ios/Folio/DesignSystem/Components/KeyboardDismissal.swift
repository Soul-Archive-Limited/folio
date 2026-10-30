import UIKit

/// Puts the keyboard away from wherever it is (a tap outside a field, Batch I).
@MainActor
enum KeyboardDismissal {
    static func dismiss() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
