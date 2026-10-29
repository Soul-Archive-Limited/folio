import SwiftUI

/// Entries grouped by month with sticky glass headers (SPEC §6.6).
struct JournalTimeline: View {
    let sections: [JournalModel.MonthSection]
    let zoom: Namespace.ID

    var body: some View {
        ForEach(sections) { section in
            Section {
                ForEach(section.entries) { entry in
                    NavigationLink(value: entry.id) {
                        JournalEntryCard(entry: entry)
                            .zoomSource(id: entry.id, in: zoom)
                    }
                    .buttonStyle(.pressable)
                    .entryActions(entry)
                    .padding(.horizontal, Spacing.sideMargin)
                }
            } header: {
                JournalMonthHeader(month: section.month, count: section.entries.count)
            }
        }
    }
}

struct JournalMonthHeader: View {
    let month: MonthKey
    let count: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(month.firstDay.utcDate, format: Date.FormatStyle(timeZone: .gmt).month(.wide).year())
                .folioFont(.headline)
                .foregroundStyle(.ink)
            Spacer()
            Text("^[\(count) page](inflect: true)")
                .folioFont(.caption)
                .foregroundStyle(.inkSecondary)
        }
        .padding(.horizontal, Spacing.m)
        .frame(minHeight: 40)
        .folioGlass(in: .capsule)
        .padding(.horizontal, Spacing.sideMargin)
        .padding(.vertical, Spacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
