import Foundation

/// One greeting line. Each has a written-out version without a name, so dropping the name
/// reads naturally in every language rather than relying on string surgery.
struct Greeting: Identifiable, Sendable {
    let id: String
    let named: @Sendable (String) -> String
    let unnamed: @Sendable () -> String

    func text(name: String?) -> String {
        if let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            named(name)
        } else {
            unnamed()
        }
    }
}
