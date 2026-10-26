import SwiftUI

/// Endless horizontal month paging (SPEC §6.2): a lazy row of months bound to the
/// model's scroll position, extended near either end.
struct MonthPager: View {
    @Bindable var model: CalendarModel
    let layout: CalendarLayout
    let firstWeekday: Int

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(model.months) { month in
                    MonthGridView(month: month, model: model, layout: layout, firstWeekday: firstWeekday)
                        .frame(width: layout.panelWidth)
                        .id(month.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $model.visibleMonthID)
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .accessibilityRotor("Days with entries") {
            ForEach(daysWithEntries, id: \.self) { day in
                AccessibilityRotorEntry(DayCellAccessibility.label(for: rotorState(day)), id: day)
            }
        }
    }

    @Environment(DiaryStore.self) private var store

    private var daysWithEntries: [DayKey] {
        let markers = store.markers(for: model.visibleMonth, firstWeekday: firstWeekday)
        return model.visibleMonth.days.filter { markers[$0]?.hasEntries == true }
    }

    private func rotorState(_ day: DayKey) -> DayCellState {
        let marker = store.markers(for: model.visibleMonth, firstWeekday: firstWeekday)[day]
        return DayCellState(day: day, marker: marker, isToday: false, isSelected: false,
                            isInMonth: true, matchesFilter: true, showsPhotoTiles: true)
    }
}
