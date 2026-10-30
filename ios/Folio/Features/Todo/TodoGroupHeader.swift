import SwiftUI

/// A To-do group's header — "TODAY · 3" — tap to fold or unfold (state persisted, Batch I).
/// Overdue is in ember so it reads first.
struct TodoGroupHeader: View {
    let title: LocalizedStringKey
    let count: Int
    var isOverdue = false
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: Spacing.xs) {
                Text(title)
                    .folioFont(.caption)
                    .foregroundStyle(isOverdue ? AnyShapeStyle(.emberText) : AnyShapeStyle(.inkSecondary))
                Text(count, format: .number)
                    .folioFont(.caption)
                    .foregroundStyle(.inkTertiary)
                    .monospacedDigit()
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.inkSecondary)
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
            }
            .contentShape(.rect)
            .frame(minHeight: Spacing.minHitTarget)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text("\(count), \(isExpanded ? String(localized: "expanded") : String(localized: "collapsed"))"))
        .accessibilityAddTraits(.isHeader)
    }
}

/// The top bar's date button: shows one date's tasks only (Batch I). Shows the date while a
/// filter is on; the popover has "Show all dates".
struct TodoDateFilterButton: View {
    @Binding var day: DayKey?
    let today: DayKey

    @State private var picking = false
    @Environment(DiaryStore.self) private var store

    var body: some View {
        Button { picking = true } label: {
            if day == nil {
                Label("Show one date", systemImage: "calendar")
            } else {
                Label(label, systemImage: "calendar").labelStyle(.titleAndIcon)
            }
        }
        .tint(day == nil ? .ink : .emberStrong)
        .accessibilityLabel(day == nil ? Text("Show one date") : Text("Showing \(label)"))
        .popover(isPresented: $picking) {
            VStack(spacing: Spacing.s) {
                DatePicker("Date", selection: dateBinding, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                if day != nil {
                    Button("Show all dates", systemImage: "xmark.circle") {
                        day = nil
                        picking = false
                    }
                    .tint(.emberStrong)
                }
            }
            .padding()
            .frame(minWidth: 320)
            .presentationCompactAdaptation(.popover)
        }
    }

    private var label: String {
        guard let day else { return String(localized: "All dates") }
        if day == today { return String(localized: "Today") }
        return day.utcDate.formatted(Date.FormatStyle(timeZone: .gmt).weekday(.abbreviated).day().month(.abbreviated))
    }

    private var dateBinding: Binding<Date> {
        Binding(get: { (day ?? today).startDate(in: store.calendar) },
                set: { date in
                    day = DayKey(date: date, calendar: store.calendar)
                    picking = false
                })
    }
}
