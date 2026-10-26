import SwiftUI

/// The collapsed calendar: a swipeable strip of weeks (SPEC §6.2).
struct WeekPager: View {
    @Bindable var model: CalendarModel
    let layout: CalendarLayout
    let firstWeekday: Int

    @Environment(DiaryStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(PreferenceKeys.showPhotoTiles) private var showsPhotoTiles = true
    @State private var weeks: [DayKey] = []

    static let radius = 260

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(weeks, id: \.self) { weekStart in
                    WeekRowView(weekStart: weekStart, model: model, layout: layout, firstWeekday: firstWeekday,
                                showsPhotoTiles: showsPhotoTiles)
                        .frame(width: layout.panelWidth)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $model.visibleWeekID)
        .scrollIndicators(.hidden)
        .onAppear(perform: buildWeeks)
        .onChange(of: model.visibleWeekID) { _, weekStart in
            if let weekStart { model.weekDidChange(to: weekStart) }
        }
    }

    private func buildWeeks() {
        let start = Self.weekStart(of: model.selectedDay, firstWeekday: firstWeekday)
        weeks = (-Self.radius...Self.radius).map { start.adding(days: $0 * 7) }
        model.visibleWeekID = start
    }

    static func weekStart(of day: DayKey, firstWeekday: Int) -> DayKey {
        day.adding(days: -((day.weekday - firstWeekday + 7) % 7))
    }
}
