import SwiftUI

/// Jump to any month (SPEC §6.3): snapping year strip, 4×3 months, Go to today.
struct JumpSheet: View {
    @Bindable var model: CalendarModel

    @Environment(DiaryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var year: Int?

    var body: some View {
        let selectedYear = year ?? model.visibleMonth.year
        VStack(spacing: Spacing.l) {
            YearStrip(selectedYear: Binding(get: { year ?? model.visibleMonth.year }, set: { year = $0 }),
                      years: Array(1900...(store.today.year + 10)))
            MonthCapsuleGrid(year: selectedYear, current: model.visibleMonth,
                             monthsWithEntries: store.monthsWithEntries(in: selectedYear)) { month in
                go(to: month)
            }
            .padding(.horizontal, Spacing.sideMargin)
            Button("Go to today", systemImage: "calendar.badge.clock", action: goToToday)
                .buttonStyle(.glass)
        }
        .padding(.vertical, Spacing.l)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .privacyCovered()
        .onAppear { year = model.visibleMonth.year }
    }

    private func go(to month: MonthKey) {
        model.jump(to: month)
        dismiss()
    }

    private func goToToday() {
        let today = store.today
        model.jump(to: today.monthKey, selecting: today)
        dismiss()
    }
}
