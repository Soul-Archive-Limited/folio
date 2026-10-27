import SwiftUI

/// "Nothing here yet." with Write and Add task (SPEC §6.2).
struct DayPanelEmptyState: View {
    let day: DayKey
    @Environment(\.newItemRequest) private var request

    var body: some View {
        VStack(spacing: Spacing.m) {
            Text("Nothing here yet.")
                .folioFont(.callout)
                .foregroundStyle(.inkSecondary)
            GlassEffectContainer(spacing: Spacing.s) {
                HStack(spacing: Spacing.s) {
                    Button("Write", systemImage: "square.and.pencil") { request?.send(.entry(day)) }
                        .buttonStyle(.glassProminent)
                        .tint(.emberStrong)
                    Button("Add task", systemImage: "checklist") { request?.send(.task(day)) }
                        .buttonStyle(.glass)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
        .staggeredAppear(index: 0)
    }
}
