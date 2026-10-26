import SwiftUI

/// At accessibility text sizes the 7-column grid can't fit, so the month becomes a list of
/// week rows: one row per day with its markers spelled out (SPEC §3.9).
struct AccessibleMonthList: View {
    @Bindable var model: CalendarModel
    let onTitleTap: () -> Void

    @Environment(DiaryStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let month = model.visibleMonth
        let firstWeekday = store.settings().firstWeekday ?? store.calendar.firstWeekday
        let markers = store.markers(for: month, firstWeekday: firstWeekday)
        let today = store.today
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.m) {
                CalendarHeader(model: model, onTitleTap: onTitleTap)
                HStack {
                    GlassIconButton(title: "Previous month", systemImage: "chevron.left") { step(-1) }
                    Spacer()
                    GlassIconButton(title: "Next month", systemImage: "chevron.right") { step(1) }
                }
                .padding(.horizontal, Spacing.sideMargin)
                ForEach(month.days, id: \.self) { day in
                    let state = DayCellState(day: day, marker: markers[day], isToday: day == today,
                                             isSelected: day == model.selectedDay, isInMonth: true,
                                             matchesFilter: true, showsPhotoTiles: false)
                    Button { model.select(day, reduceMotion: reduceMotion) } label: {
                        Text(DayCellAccessibility.label(for: state))
                            .folioFont(.body)
                            .foregroundStyle(day == model.selectedDay ? AnyShapeStyle(.white) : AnyShapeStyle(.ink))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Spacing.m)
                            .folioGlass(in: .rect(cornerRadius: Radius.card), interactive: true,
                                        solidFill: day == model.selectedDay ? .ember : nil)
                    }
                    .buttonStyle(.pressable)
                    .padding(.horizontal, Spacing.sideMargin)
                }
                DayPanel(model: model, onTitleTap: {})
                    .padding(.horizontal, Spacing.sideMargin)
                    .padding(.bottom, 120)
            }
        }
    }

    private func step(_ months: Int) {
        let target = model.visibleMonth.adding(months: months)
        model.jump(to: target, selecting: target.firstDay)
    }
}
