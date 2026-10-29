import SwiftUI

/// The selected day's entries and tasks, under the grid (SPEC §6.2).
struct DayPanel: View {
    let model: CalendarModel
    /// Entry cards are the source of the zoom into entry detail (SPEC §3.6).
    let zoomNamespace: Namespace.ID?
    let onTitleTap: () -> Void

    @Environment(DiaryStore.self) private var store
    @Environment(\.newItemRequest) private var request
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let day = model.selectedDay
        let entries = store.entries(on: day)
        let tasks = store.tasks(on: day)
        let categories = Dictionary(uniqueKeysWithValues: store.categories().map { ($0.id, $0) })

        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack {
                Button(action: onTitleTap) {
                    Text(day.utcDate, format: Date.FormatStyle(timeZone: .gmt).weekday(.wide).day().month(.wide))
                        .folioFont(.title2)
                        .foregroundStyle(.ink)
                        .multilineTextAlignment(.leading)
                        // The title stays put and cross-fades; only the rows below re-enter.
                        .contentTransition(.opacity)
                        .animation(FolioMotion.standard(reduceMotion: reduceMotion), value: day)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(.isHeader)
                Spacer()
                GlassIconButton(title: "New entry for this day", systemImage: "plus") { request?.send(.entry(day)) }
            }

            VStack(alignment: .leading, spacing: Spacing.m) {
                if entries.isEmpty && tasks.isEmpty {
                    DayPanelEmptyState(day: day)
                } else {
                    if !entries.isEmpty {
                        PanelSectionTitle(title: "Pages")
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                            NavigationLink(value: entry.id) {
                                EntryCard(entry: entry, category: entry.categoryID.flatMap { categories[$0] }, calendar: store.calendar)
                                    .zoomSource(id: entry.id, in: zoomNamespace)
                            }
                            .buttonStyle(.pressable)
                            .entryActions(entry)
                            .staggeredAppear(index: index)
                        }
                    }
                    if !tasks.isEmpty {
                        PanelSectionTitle(title: "Tasks")
                        VStack(spacing: 0) {
                            ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                                DayTaskRow(task: task, tint: task.categoryID.flatMap { categories[$0]?.color.color } ?? .ink) {
                                    store.setCompleted(task, !task.isCompleted)
                                }
                                .staggeredAppear(index: entries.count + index)
                            }
                        }
                        .padding(.horizontal, Spacing.xs)
                        .folioGlass(in: .rect(cornerRadius: Radius.card))
                    }
                }
            }
            .id(day)
        }
    }
}

/// Small uppercase section heading.
struct PanelSectionTitle: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .folioFont(.caption)
            .foregroundStyle(.inkSecondary)
            .accessibilityAddTraits(.isHeader)
    }
}
