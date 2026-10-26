import SwiftUI

/// Month + year title (tap → Jump sheet) and the glass Filter / Today group (SPEC §6.2).
struct CalendarHeader: View {
    @Bindable var model: CalendarModel
    /// Opens the Jump sheet, or expands the grid when it's collapsed.
    let onTitleTap: () -> Void

    @Environment(DiaryStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var glass

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Button(action: onTitleTap) {
                MonthTitle(month: model.visibleMonth)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(model.visibleMonth.firstDay.utcDate.formatted(Date.FormatStyle(timeZone: .gmt).month(.wide).year()))
            .accessibilityHint(model.isCollapsed ? "Shows the whole month" : "Opens the month and year picker")

            Spacer(minLength: Spacing.s)

            GlassEffectContainer(spacing: Spacing.xs) {
                HStack(spacing: Spacing.xs) {
                    if showsToday {
                        Button("Today", action: goToToday)
                            .font(.subheadline.weight(.semibold))
                            .buttonStyle(.glass)
                            .glassEffectID("today", in: glass)
                            .glassEffectTransition(.matchedGeometry)
                    }
                    CalendarFilterMenu(model: model)
                        .glassEffectID("filter", in: glass)
                }
            }
            .animation(FolioMotion.standard(reduceMotion: reduceMotion), value: showsToday)
        }
        .padding(.horizontal, Spacing.sideMargin)
    }

    /// The Today pill appears only when away from today or its month (SPEC §6.2).
    private var showsToday: Bool {
        let today = store.today
        return model.selectedDay != today || model.visibleMonth != today.monthKey
    }

    private func goToToday() {
        model.goToToday(store.today, reduceMotion: reduceMotion)
    }
}
