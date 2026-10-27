import SwiftUI

/// The glass panel holding the grid. Its height follows the collapse progress 1:1; once
/// fully collapsed the month pager becomes a week strip.
struct CalendarGridArea: View {
    @Bindable var model: CalendarModel
    let layout: CalendarLayout
    let firstWeekday: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(TourModel.self) private var tour: TourModel?
    @State private var jumpScale = 1.0
    @State private var jumpOpacity = 1.0

    var body: some View {
        ZStack(alignment: .top) {
            if model.isCollapsed {
                WeekPager(model: model, layout: layout, firstWeekday: firstWeekday)
            } else {
                // Full height, pinned to the top: the panel clips it as it shrinks. (A shorter
                // horizontal scroll view would centre the grid and double the movement.)
                MonthPager(model: model, layout: layout, firstWeekday: firstWeekday)
                    .frame(height: layout.fullGridHeight, alignment: .top)
                    .scaleEffect(jumpScale)
                    .opacity(jumpOpacity)
            }
        }
        .frame(width: layout.panelWidth, height: layout.gridHeight(progress: model.collapseProgress),
               alignment: .top)
        .clipShape(.rect(cornerRadius: Radius.card))
        .contentShape(.rect(cornerRadius: Radius.card))
        .folioGlass(in: .rect(cornerRadius: Radius.card))
        .tourAnchor(.month, tour)
        .onChange(of: model.jumpCount) { playJump() }
        .onChange(of: model.visibleMonthID) { _, id in
            if let id { model.monthDidChange(to: MonthKey(year: 0, month: id + 1)) }
        }
        .folioHaptic(.selection, trigger: model.selectionHapticCount)
    }

    /// Jump sheet / Today: a quick fade + scale instead of scrolling through months.
    private func playJump() {
        jumpOpacity = 0
        jumpScale = reduceMotion ? 1 : 0.96
        withAnimation(FolioMotion.standard(reduceMotion: reduceMotion)) {
            jumpOpacity = 1
            jumpScale = 1
        }
    }
}
