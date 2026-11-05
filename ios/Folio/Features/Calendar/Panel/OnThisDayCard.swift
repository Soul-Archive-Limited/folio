import SwiftUI

/// "On this day" at the top of the day panel (Batch J): pages written on this date in earlier
/// years, newest first, three at most. Nothing shows when there are none.
struct OnThisDayCard: View {
    let day: DayKey
    @Environment(DiaryStore.self) private var store

    var body: some View {
        let earlier = store.entriesOnSameDay(as: day, excluding: UUID()).filter { ($0.day?.year ?? .max) < day.year }
        if !earlier.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Label("On this day", systemImage: "clock.arrow.circlepath")
                    .folioFont(.caption)
                    .foregroundStyle(.ember)
                ForEach(earlier.prefix(3)) { entry in
                    NavigationLink(value: entry.id) {
                        HStack(spacing: Spacing.s) {
                            Text(String(entry.day?.year ?? 0))
                                .font(.subheadline.weight(.bold).monospacedDigit())
                                .foregroundStyle(.ink)
                            Text(entry.title.isEmpty ? String(localized: "Untitled") : entry.title)
                                .folioFont(.callout)
                                .foregroundStyle(.inkSecondary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            if let mood = entry.mood.flatMap(Mood.init(rawValue:)) { MoodGlyph(mood: mood, size: 12) }
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.inkTertiary)
                        }
                        .frame(minHeight: 32)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel(String(localized: "\(String(entry.day?.year ?? 0)), \(entry.title)"))
                }
                if earlier.count > 3 {
                    Text("and \(earlier.count - 3) more").folioFont(.caption).foregroundStyle(.inkSecondary)
                }
            }
            .padding(Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .folioGlass(in: .rect(cornerRadius: Radius.card), behindContent: true)
            .accessibilityIdentifier("day.onThisDay")
        }
    }
}
