import SwiftUI

/// Seven day cells for one week of the collapsed strip.
struct WeekRowView: View {
    let weekStart: DayKey
    let model: CalendarModel
    let layout: CalendarLayout
    let firstWeekday: Int
    let showsPhotoTiles: Bool

    @Environment(DiaryStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let days = (0..<7).map { weekStart.adding(days: $0) }
        let today = store.today
        let markers = markers(for: days)
        let categoryColors = Dictionary(uniqueKeysWithValues: store.categories().map { ($0.id, $0.color.color) })
        HStack(spacing: CalendarLayout.gap) {
            ForEach(days, id: \.self) { day in
                DayCell(
                    state: DayCellState(day: day, marker: markers[day], isToday: day == today,
                                        isSelected: day == model.selectedDay, isInMonth: true,
                                        matchesFilter: true, showsPhotoTiles: showsPhotoTiles),
                    size: layout.cellSize,
                    categoryColor: { $0.flatMap { categoryColors[$0] } ?? .inkSecondary },
                    onTap: { model.selectedDay = day }
                )
                .contextMenu { DayContextMenu(day: day) }
            }
        }
        .padding(CalendarLayout.panelPadding)
        .frame(width: layout.panelWidth)
    }

    /// A week can straddle two months; merge both months' cached markers.
    private func markers(for days: [DayKey]) -> [DayKey: DayMarker] {
        Set(days.map(\.monthKey)).reduce(into: [:]) { result, month in
            result.merge(store.markers(for: month, firstWeekday: firstWeekday)) { first, _ in first }
        }
    }
}
