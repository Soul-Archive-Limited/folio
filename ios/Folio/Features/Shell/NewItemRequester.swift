import SwiftUI

/// Lets deep views (day cells, the day panel) ask the shell to open a composer without
/// threading a closure through every initialiser. A class, so the environment value stays
/// stable (swiftui-pro: no stored closures in the environment).
@Observable
final class NewItemRequester {
    var pending: NewItemRequest?

    func send(_ request: NewItemRequest) {
        pending = request
    }
}

extension EnvironmentValues {
    @Entry var newItemRequest: NewItemRequester?
}
