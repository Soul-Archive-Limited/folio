import SwiftUI

/// One month's 6×7 grid. While collapsing, the selected week slides to the top and the
/// other weeks fade, so the collapse reads as one continuous motion (SPEC §6.2).
struct MonthGridView: View {
    let month: MonthKey
    let model: CalendarModel
    let layout: CalendarLayout
    let firstWeekday: Int

    @Environment(DiaryStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(PreferenceKeys.showPhotoTiles) private var showsPhotoTiles = true
    @Environment(TourModel.self) private var tour: TourModel?

    var body: some View {
        let days = month.gridDays(firstWeekday: firstWeekday)
        let markers = store.markers(for: month, firstWeekday: firstWeekday)
        let today = store.today
        let selectedRow = month == model.selectedDay.monthKey ? model.selectedRow(firstWeekday: firstWeekday) : 0
        let progress = model.collapseProgress
        let categoryColors = Dictionary(uniqueKeysWithValues: store.categories().map { ($0.id, $0.color.color) })

        VStack(spacing: CalendarLayout.gap) {
            ForEach(0..<6, id: \.self) { row in
                HStack(spacing: CalendarLayout.gap) {
                    ForEach(days[(row * 7)..<(row * 7 + 7)], id: \.self) { day in
                        // Out-of-month days are just a faded number: no photos, dots, rings or checks.
                        let inMonth = day.monthKey == month
                        DayCell(
                            state: DayCellState(
                                day: day, marker: inMonth ? markers[day] : nil, isToday: inMonth && day == today,
                                isSelected: day == model.selectedDay, isInMonth: inMonth,
                                matchesFilter: model.matchesFilter(markers[day]), showsPhotoTiles: showsPhotoTiles
                            ),
                            size: layout.cellSize,
                            categoryColor: { $0.flatMap { categoryColors[$0] } ?? .inkSecondary },
                            onTap: { tap(day) }
                        )
                        .contextMenu {
                            DayContextMenu(day: day)
                        }
                        .modifier(TodayTourTip(isToday: inMonth && day == today, tour: tour))
                    }
                }
                .opacity(row == selectedRow ? 1 : 1 - progress)
            }
        }
        .offset(y: -Double(selectedRow) * layout.rowHeight * progress)
        .padding(CalendarLayout.panelPadding)
        .frame(width: layout.panelWidth, alignment: .top)
    }

    private func tap(_ day: DayKey) {
        model.select(day, reduceMotion: reduceMotion)
        tour?.didSelectDay()
    }
}

/// Tour step 2 points at today's cell (SPEC §6.15).
private struct TodayTourTip: ViewModifier {
    let isToday: Bool
    let tour: TourModel?

    func body(content: Content) -> some View {
        if isToday { content.tourTip(TapDayTip.self, tour, arrowEdge: .top) } else { content }
    }
}
