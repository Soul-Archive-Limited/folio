import SwiftUI

/// "What do the marks mean?" (Batch I): the calendar's marks drawn with the real day cell, one
/// line each. Opens from Profile → Help and a long-press on the weekday row.
struct MarkersKeyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DiaryStore.self) private var store

    private struct Row: Identifiable {
        let id: Int
        let state: DayCellState
        let title: LocalizedStringKey
        let detail: LocalizedStringKey
    }

    private var rows: [Row] {
        let day = DayKey(year: 2026, month: 10, day: 14) ?? DayKey(date: .now, calendar: .current)
        func state(_ marker: DayMarker?, today: Bool = false, selected: Bool = false) -> DayCellState {
            DayCellState(day: day, marker: marker, isToday: today, isSelected: selected, isInMonth: true,
                         matchesFilter: true, showsPhotoTiles: true)
        }
        return [
            Row(id: 0, state: state(nil, today: true), title: "Today", detail: "An ember number in a thin ember outline."),
            Row(id: 1, state: state(nil, selected: true), title: "Selected day", detail: "Filled ember. Its pages and tasks show below."),
            Row(id: 2, state: state(DayMarker(entryCount: 2, dotCategoryIDs: [nil, nil])), title: "Pages",
                detail: "A dot under the number for each page, in its category's colour (up to three)."),
            Row(id: 3, state: state(DayMarker(entryCount: 1, thumbnailPhotoID: photoID)), title: "Photo",
                detail: "The day's latest photo fills the square. “+2” means more pages that day."),
            Row(id: 4, state: state(DayMarker(openTaskCount: 1)), title: "Tasks to do", detail: "A small ring in the corner."),
            Row(id: 5, state: state(DayMarker(doneTaskCount: 2)), title: "All tasks done", detail: "A green tick in the same corner."),
        ]
    }

    /// One of the diary's own photos, or an empty tile when there are none.
    private var photoID: UUID {
        store.latestPhotoID ?? UUID(uuidString: "00000000-0000-4000-8000-00000000F0F0") ?? UUID()
    }

    var body: some View {
        NavigationStack {
            List(rows) { row in
                HStack(spacing: Spacing.m) {
                    DayCell(state: row.state, size: 44, categoryColor: { _ in .ember }, onTap: {})
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.title).folioFont(.headline).foregroundStyle(.ink)
                        Text(row.detail).folioFont(.callout).foregroundStyle(.inkSecondary)
                    }
                }
                .padding(.vertical, Spacing.xxs)
                .accessibilityElement(children: .combine)
                .listRowBackground(ProfileRowBackground())
            }
            .scrollContentBackground(.hidden)
            .background { AuraBackground() }
            .navigationTitle("What the marks mean")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
