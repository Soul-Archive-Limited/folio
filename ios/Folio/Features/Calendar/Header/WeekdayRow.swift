import SwiftUI

/// Weekday initials in `caption` / `inkTertiary`, starting on the chosen first weekday.
struct WeekdayRow: View {
    let firstWeekday: Int
    let layout: CalendarLayout

    var body: some View {
        HStack(spacing: CalendarLayout.gap) {
            ForEach(0..<7, id: \.self) { offset in
                let weekday = (firstWeekday - 1 + offset) % 7
                Text(Self.symbols[weekday])
                    .folioFont(.caption)
                    .foregroundStyle(.inkTertiary)
                    .frame(width: layout.cellSize)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, CalendarLayout.panelPadding)
        .frame(maxWidth: .infinity)
    }

    static var symbols: [String] {
        Calendar.current.veryShortStandaloneWeekdaySymbols.count == 7
            ? Calendar.current.shortStandaloneWeekdaySymbols.map { String($0.prefix(3)) }
            : ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    }
}
