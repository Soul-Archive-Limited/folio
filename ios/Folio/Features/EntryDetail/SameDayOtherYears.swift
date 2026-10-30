import SwiftUI

/// "On this day" (SPEC §6.5, renamed in Batch I): entries on this calendar date in other
/// years, with a subtitle that says so ("You wrote on 29 October in 2025").
struct SameDayOtherYears: View {
    let day: DayKey
    let excluding: UUID

    @Environment(DiaryStore.self) private var store

    var body: some View {
        let entries = store.entriesOnSameDay(as: day, excluding: excluding)
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.s) {
                VStack(alignment: .leading, spacing: 2) {
                    PanelSectionTitle(title: "On this day")
                    Text(subtitle(entries))
                        .folioFont(.callout)
                        .foregroundStyle(.inkSecondary)
                }
                // Cards sit straight on the page (owner review, Batch B): a clipping scroll
                // view gives glass its own backdrop, which showed as a lighter band.
                ScrollView(.horizontal) {
                    GlassEffectContainer(spacing: 0) {
                        HStack(alignment: .top, spacing: Spacing.s) {
                            ForEach(entries) { entry in
                                NavigationLink(value: entry.id) {
                                    OtherYearCard(entry: entry)
                                }
                                .buttonStyle(.pressable)
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
            }
            .padding(.top, Spacing.l)
        }
    }
}

extension SameDayOtherYears {
    /// "You wrote on 29 October in 2025" / "… in 2023 and 2025" / "… in 2019, 2023 and 2025".
    func subtitle(_ entries: [Entry]) -> String {
        Self.subtitle(day: day, years: entries.compactMap(\.day?.year))
    }

    static func subtitle(day: DayKey, years: [Int], locale: Locale = .current) -> String {
        let date = day.utcDate.formatted(Date.FormatStyle(locale: locale, timeZone: .gmt).day().month(.wide))
        let unique = Array(Set(years)).sorted().map { String($0) }
        let list = unique.formatted(.list(type: .and).locale(locale))
        return String(localized: "You wrote on \(date) in \(list)")
    }
}

struct OtherYearCard: View {
    let entry: Entry

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(entry.day?.year ?? 0, format: .number.grouping(.never))
                .folioFont(.title2)
                .foregroundStyle(.emberText)
            Text(entry.title.isEmpty ? String(localized: "Untitled") : entry.title)
                .folioFont(.callout)
                .foregroundStyle(.ink)
                .lineLimit(2)
        }
        .padding(Spacing.s)
        .frame(width: 160, height: 96, alignment: .topLeading)
        .folioGlass(in: .rect(cornerRadius: Radius.card), interactive: true)
        .accessibilityElement(children: .combine)
    }
}
