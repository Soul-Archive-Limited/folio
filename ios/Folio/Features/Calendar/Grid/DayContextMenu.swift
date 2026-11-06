import SwiftUI

/// Long-press menu on a day (SPEC §6.2): new entry or task for that day.
struct DayContextMenu: View {
    let day: DayKey
    @Environment(\.newItemRequest) private var request

    var body: some View {
        Button("New entry", image: .folioPageNew) { request?.send(.entry(day)) }
        Button("New task", image: .folioTodo) { request?.send(.task(day)) }
    }
}
