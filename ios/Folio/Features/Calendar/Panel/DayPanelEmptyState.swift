import SwiftUI

/// An empty day: one calm line and a single "Add task" (SPEC §6.2, Batch K). A page comes from
/// the floating +, so there's no second Write button here.
struct DayPanelEmptyState: View {
    let day: DayKey
    @Environment(\.newItemRequest) private var request

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Text("Nothing written yet.")
                .foregroundStyle(.inkSecondary)
            Button("Add task") { request?.send(.task(day)) }
                .buttonStyle(.plain)
                .foregroundStyle(.emberText)
                .fontWeight(.semibold)
                .frame(minHeight: 44)
                .contentShape(.rect)
        }
        .folioFont(.callout)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.l)
        .staggeredAppear(index: 0)
    }
}
