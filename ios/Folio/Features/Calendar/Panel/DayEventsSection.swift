import SwiftUI

/// The day's Apple Calendar events in the day panel (Batch J): read-only, from this iPhone.
struct DayEventsSection: View {
    let events: [CalendarEvents.Event]
    let day: DayKey
    let calendar: Calendar

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            PanelSectionTitle(title: "Calendar")
            VStack(spacing: 0) {
                ForEach(events) { event in
                    HStack(spacing: Spacing.s) {
                        Capsule().fill(event.color).frame(width: 3, height: 22)
                        Text(time(event))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.inkSecondary)
                            .frame(width: 84, alignment: .leading)
                        Text(event.title).folioFont(.callout).foregroundStyle(.ink).lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: 36)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xxs)
            .folioGlass(in: .rect(cornerRadius: Radius.card))
        }
        .accessibilityIdentifier("day.calendarEvents")
    }

    private func time(_ event: CalendarEvents.Event) -> String {
        if event.isAllDay { return String(localized: "All day") }
        let start = DayKey(date: event.start, calendar: calendar)
        let end = DayKey(date: event.end.addingTimeInterval(-1), calendar: calendar)
        let style = Date.FormatStyle(calendar: calendar, timeZone: calendar.timeZone).hour().minute()
        if start < day && end > day { return String(localized: "All day") }
        if start < day { return String(localized: "until \(event.end.formatted(style))") }
        return event.start.formatted(style)
    }
}
