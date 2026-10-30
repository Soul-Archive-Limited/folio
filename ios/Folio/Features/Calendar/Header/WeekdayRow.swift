import SwiftUI

/// Weekday initials in `caption` / `inkSecondary` (AA contrast; DECISIONS 211), starting on the chosen first weekday.
struct WeekdayRow: View {
    let firstWeekday: Int
    let layout: CalendarLayout
    @State private var showsKey = false

    var body: some View {
        HStack(spacing: CalendarLayout.gap) {
            ForEach(0..<7, id: \.self) { offset in
                let weekday = (firstWeekday - 1 + offset) % 7
                Text(Self.symbols[weekday])
                    .folioFont(.caption)
                    .foregroundStyle(.inkSecondary)
                    .frame(width: layout.cellSize)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, CalendarLayout.panelPadding)
        .frame(maxWidth: .infinity)
        // Long-press the weekdays for the key to the marks (Batch I).
        .contentShape(.rect)
        .onLongPressGesture(minimumDuration: 0.4) { showsKey = true }
        .accessibilityElement()
        .accessibilityLabel("Weekdays")
        .accessibilityAction(named: "What do the marks mean?") { showsKey = true }
        .sheet(isPresented: $showsKey) { MarkersKeyView() }
        .folioHaptic(.selection, trigger: showsKey)
    }

    static var symbols: [String] {
        Calendar.current.veryShortStandaloneWeekdaySymbols.count == 7
            ? Calendar.current.shortStandaloneWeekdaySymbols.map { String($0.prefix(3)) }
            : ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    }
}
