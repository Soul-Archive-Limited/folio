import SwiftUI

/// "Your archive" (SPEC §6.9): Entries · Photos · Days written on · Tasks done. Each tile
/// opens its tab, filtered.
struct ProfileArchiveTiles: View {
    @Environment(DiaryStore.self) private var store
    @Environment(\.tabRouter) private var router

    var body: some View {
        let stats = store.profileStats()
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Your archive")
                .folioFont(.caption)
                .foregroundStyle(.inkTertiary)
                .padding(.leading, Spacing.xxs)
                .accessibilityAddTraits(.isHeader)
            Grid(horizontalSpacing: Spacing.s, verticalSpacing: Spacing.s) {
                GridRow {
                    tile("Entries", value: stats.entries, systemImage: "book.pages", to: .entries)
                    tile("Photos", value: stats.photos, systemImage: "photo.on.rectangle", to: .photos)
                }
                GridRow {
                    tile("Days written on", value: stats.daysWrittenOn, systemImage: "calendar", to: .daysWrittenOn)
                    tile("Tasks done", value: stats.tasksDone, systemImage: "checkmark.circle", to: .tasksDone)
                }
            }
        }
    }

    private func tile(_ title: LocalizedStringKey, value: Int, systemImage: String, to destination: TabRouter.Destination) -> some View {
        Button { router?.open(destination) } label: {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Image(systemName: systemImage)
                    .font(.headline)
                    .foregroundStyle(.ember)
                Text(value, format: .number)
                    .folioFont(.title2)
                    .foregroundStyle(.ink)
                    .contentTransition(.numericText())
                Text(title)
                    .folioFont(.caption)
                    .foregroundStyle(.inkSecondary)
            }
            .padding(Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .folioGlass(in: .rect(cornerRadius: Radius.card), interactive: true)
        }
        .buttonStyle(.pressable)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens it")
    }
}
