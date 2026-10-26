import SwiftUI

/// "Same day in other years" (SPEC §6.5): entries on this calendar date in other years.
struct SameDayOtherYears: View {
    let day: DayKey
    let excluding: UUID

    @Environment(DiaryStore.self) private var store

    var body: some View {
        let entries = store.entriesOnSameDay(as: day, excluding: excluding)
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.s) {
                PanelSectionTitle(title: "Same day in other years")
                ScrollView(.horizontal) {
                    HStack(spacing: Spacing.s) {
                        ForEach(entries) { entry in
                            NavigationLink(value: entry.id) {
                                OtherYearCard(entry: entry)
                            }
                            .buttonStyle(.pressable)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
            .padding(.top, Spacing.l)
        }
    }
}

struct OtherYearCard: View {
    let entry: Entry

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(entry.day?.year ?? 0, format: .number.grouping(.never))
                .folioFont(.title2)
                .foregroundStyle(.ember)
            Text(entry.title.isEmpty ? String(localized: "Untitled") : entry.title)
                .folioFont(.callout)
                .foregroundStyle(.ink)
                .lineLimit(2)
        }
        .padding(Spacing.s)
        .frame(width: 160, alignment: .leading)
        .folioGlass(in: .rect(cornerRadius: Radius.card), interactive: true)
        .accessibilityElement(children: .combine)
    }
}
