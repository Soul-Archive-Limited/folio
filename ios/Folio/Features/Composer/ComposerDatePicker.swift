import SwiftUI

/// Graphical date picker from 1 January 1900 to ten years ahead, plus an optional time.
struct ComposerDatePicker: View {
    @Binding var day: DayKey
    @Binding var minutes: Int?

    @Environment(DiaryStore.self) private var store

    var body: some View {
        let calendar = store.calendar
        VStack(alignment: .leading, spacing: Spacing.s) {
            DatePicker("Day", selection: dateBinding(calendar), in: range(calendar), displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(.emberStrong)
            Toggle("Time", isOn: hasTime)
                .tint(.emberStrong)
            if minutes != nil {
                DatePicker("Time", selection: timeBinding(calendar), displayedComponents: .hourAndMinute)
            }
        }
        .padding(Spacing.m)
        .frame(minWidth: 320)
    }

    private func range(_ calendar: Calendar) -> ClosedRange<Date> {
        let start = calendar.date(from: DateComponents(year: 1900, month: 1, day: 1)) ?? .distantPast
        let end = calendar.date(byAdding: .year, value: 10, to: .now) ?? .distantFuture
        return start...end
    }

    private func dateBinding(_ calendar: Calendar) -> Binding<Date> {
        Binding(get: { day.startDate(in: calendar) }, set: { day = DayKey(date: $0, calendar: calendar) })
    }

    private func timeBinding(_ calendar: Calendar) -> Binding<Date> {
        Binding(
            get: { calendar.date(byAdding: .minute, value: minutes ?? 0, to: day.startDate(in: calendar)) ?? .now },
            set: {
                let parts = calendar.dateComponents([.hour, .minute], from: $0)
                minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }

    private var hasTime: Binding<Bool> {
        Binding(get: { minutes != nil }, set: { newValue in
            if newValue {
                let parts = store.calendar.dateComponents([.hour, .minute], from: AppClock.now)
                minutes = (parts.hour ?? 12) * 60 + (parts.minute ?? 0)
            } else {
                minutes = nil
            }
        })
    }
}
