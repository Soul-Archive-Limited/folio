import SwiftUI

/// Entries grouped by month (SPEC §6.6). Months fold: this month and last month start open,
/// older ones closed; a tap opens or closes one and the choice is remembered (Batch I).
struct JournalTimeline: View {
    let sections: [JournalModel.MonthSection]
    let model: JournalModel
    let today: DayKey
    let zoom: Namespace.ID

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ForEach(sections) { section in
            let isOpen = model.isOpen(section.month, today: today)
            Section {
                if isOpen {
                    entries(section)
                }
            } header: {
                JournalMonthHeader(month: section.month, count: section.entries.count, isOpen: isOpen) {
                    withAnimation(FolioMotion.standard(reduceMotion: reduceMotion)) { model.toggle(section.month, today: today) }
                }
            }
        }
    }

    @ViewBuilder private func entries(_ section: JournalModel.MonthSection) -> some View {
                ForEach(section.entries) { entry in
                    NavigationLink(value: entry.id) {
                        JournalEntryCard(entry: entry)
                            .zoomSource(id: entry.id, in: zoom)
                    }
                    .buttonStyle(.pressable)
                    .entryActions(entry)
                    .padding(.horizontal, Spacing.sideMargin)
                    .transition(.opacity)
                }
    }
}

/// A month label, deliberately unlike the entry cards (Batch I): small capitals and a count on
/// the page itself — no card, no glass — with a chevron that turns as the month folds.
struct JournalMonthHeader: View {
    let month: MonthKey
    let count: Int
    let isOpen: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text(month.firstDay.utcDate.formatted(Date.FormatStyle(timeZone: .gmt).month(.wide).year()))
                    .textCase(.uppercase)
                    .folioFont(.caption)
                    .foregroundStyle(.inkSecondary)
                Text(count, format: .number)
                    .folioFont(.caption)
                    .foregroundStyle(.inkTertiary)
                    .monospacedDigit()
                Rectangle().fill(.hairline).frame(height: 1).alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] }
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.inkSecondary)
                    .rotationEffect(.degrees(isOpen ? 0 : -90))
            }
            .padding(.horizontal, Spacing.sideMargin + Spacing.xxs)
            .frame(minHeight: Spacing.minHitTarget)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(month.firstDay.utcDate.formatted(Date.FormatStyle(timeZone: .gmt).month(.wide).year())))
        .accessibilityValue(Text("^[\(count) page](inflect: true), \(isOpen ? String(localized: "open") : String(localized: "closed"))"))
        .accessibilityHint(isOpen ? "Hides this month's pages" : "Shows this month's pages")
        .accessibilityAddTraits(.isHeader)
    }
}
