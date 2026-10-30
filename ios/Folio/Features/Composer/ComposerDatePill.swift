import SwiftUI

/// The glass date pill in the composer's top bar (SPEC §6.4): opens a date picker (back to
/// 1900) with an optional time. Animates when the day changes, including from calendar taps.
struct ComposerDatePill: View {
    @Binding var day: DayKey
    @Binding var minutes: Int?
    var opensPickerOnAppear = false

    @Environment(DiaryStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsPicker = false

    var body: some View {
        Button { showsPicker = true } label: {
            HStack(spacing: 4) {
                Text(day.utcDate.formatted(Date.FormatStyle(timeZone: .gmt).weekday(.abbreviated).day().month(.abbreviated).year(day.year == store.today.year ? .omitted : .defaultDigits)))
                    .contentTransition(.numericText())
                if let time {
                    Text(time, format: .dateTime.hour().minute())
                        .foregroundStyle(.inkSecondary)
                }
            }
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
            .padding(.horizontal, Spacing.s)
            .frame(minHeight: 36)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
        .animation(FolioMotion.standard(reduceMotion: reduceMotion), value: day)
        .folioHaptic(.selection, trigger: day)
        .accessibilityLabel("Date")
        .accessibilityValue(day.utcDate.formatted(Date.FormatStyle(timeZone: .gmt).weekday(.wide).day().month(.wide).year()))
        .accessibilityHint("Change the day this entry is for")
        .task {
            if opensPickerOnAppear {
                try? await Task.sleep(for: .milliseconds(450))
                showsPicker = true
            }
        }
        .popover(isPresented: $showsPicker) {
            ComposerDatePicker(day: $day, minutes: $minutes)
                .presentationCompactAdaptation(.popover)
        }
    }

    private var time: Date? {
        guard let minutes else { return nil }
        let calendar = store.calendar
        return calendar.date(byAdding: .minute, value: minutes, to: day.startDate(in: calendar))
    }
}
