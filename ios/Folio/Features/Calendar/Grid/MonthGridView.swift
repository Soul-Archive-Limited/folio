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
                        .modifier(TodayTourAnchor(isToday: inMonth && day == today, tour: tour))
                    }
                }
                .modifier(CollapseFade(model: model, isSelectedRow: row == selectedRow))
            }
        }
        .modifier(CollapseSlide(model: model, distance: Double(selectedRow) * layout.rowHeight))
        .padding(CalendarLayout.panelPadding)
        .frame(width: layout.panelWidth, alignment: .top)
    }

    private func tap(_ day: DayKey) {
        model.select(day, reduceMotion: reduceMotion)
        tour?.didSelectDay()
    }
}

/// The collapse reads the progress only in these two modifiers, so a drag frame changes an
/// opacity and an offset instead of re-running the grid (42 cells and a category fetch) —
/// the cause of the drag's dropped frames (Batch I, Time Profiler).
private struct CollapseFade: ViewModifier {
    let model: CalendarModel
    let isSelectedRow: Bool

    func body(content: Content) -> some View {
        content.opacity(isSelectedRow ? 1 : 1 - model.collapseProgress)
    }
}

private struct CollapseSlide: ViewModifier {
    let model: CalendarModel
    let distance: Double

    func body(content: Content) -> some View {
        content.offset(y: -distance * model.collapseProgress)
    }
}

/// Tour step 2 points at today's cell (SPEC §6.15).
private struct TodayTourAnchor: ViewModifier {
    let isToday: Bool
    let tour: TourModel?

    func body(content: Content) -> some View {
        if isToday { content.tourAnchor(.tapDay, tour) } else { content }
    }
}
