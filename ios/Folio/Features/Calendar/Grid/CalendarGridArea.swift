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
                    .id(layout.panelWidth)
            } else {
                // Full height, pinned to the top: the panel clips it as it shrinks. (A shorter
                // horizontal scroll view would centre the grid and double the movement.)
                // A new width rebuilds the pager at the visible month: a paging scroll view
                // keeps its old offset when its pages resize, which showed two half months.
                MonthPager(model: model, layout: layout, firstWeekday: firstWeekday)
                    .id(layout.panelWidth)
                    .frame(height: layout.fullGridHeight, alignment: .top)
                    .scaleEffect(jumpScale)
                    .opacity(jumpOpacity)
            }
        }
        .modifier(CollapsingHeight(model: model, layout: layout))
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

/// The panel's height follows the collapse 1:1; only this modifier reads the progress, so the
/// grid area's body doesn't re-run on every drag frame.
private struct CollapsingHeight: ViewModifier {
    let model: CalendarModel
    let layout: CalendarLayout

    func body(content: Content) -> some View {
        content.frame(width: layout.panelWidth, height: layout.gridHeight(progress: model.collapseProgress), alignment: .top)
    }
}
