import SwiftUI

/// The To-do tab (SPEC §6.7).
struct TodoScreen: View {
    @Environment(DiaryStore.self) private var store
    @Environment(ToastCenter.self) private var toasts
    @Environment(\.newItemRequest) private var request
    @State private var model = TodoModel()
    @AppStorage(PreferenceKeys.todoCompletedExpanded) private var showsCompleted = true
    @State private var editing: TaskItem?
    @State private var rescheduling: TaskItem?
    @State private var confirmingDelete: TaskItem?

    var body: some View {
        let today = store.today
        let sections = model.sections(from: store.allTasks(), today: today)
        let colors = Dictionary(uniqueKeysWithValues: store.categories().map { ($0.id, $0.color.color) })
        NavigationStack {
            List {
                Section {
                    CategoryFilterBar(selection: $model.filter)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                Section {
                    if sections.active.isEmpty {
                        EmptyStateView(systemImage: "checkmark.seal", message: "All clear.")
                            .frame(maxWidth: .infinity)
                            .listRowBackground(Color.clear)
                    }
                    ForEach(sections.overdue + sections.dated) { task in
                        row(task, colors: colors, today: today)
                    }
                    ForEach(sections.undated) { task in
                        row(task, colors: colors, today: today)
                    }
                    .onMove { indices, offset in move(sections.undated, indices: indices, offset: offset) }
                }
                if !sections.completed.isEmpty {
                    Section {
                        if showsCompleted {
                            ForEach(sections.completed) { task in
                                row(task, colors: colors, today: today)
                            }
                        }
                    } header: {
                        TodoCompletedHeader(count: sections.completed.count, isExpanded: $showsCompleted)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background { AuraBackground() }
            // The inset holds the toast and the quick-add bar, so the last row always scrolls
            // clear of both and of the tab bar; the margin adds a little air under it.
            .contentMargins(.bottom, Spacing.m, for: .scrollContent)
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
            .animation(FolioMotion.standard(), value: sections.active.map(\.id))
            .animation(FolioMotion.standard(), value: sections.completed.map(\.id))
            .navigationTitle("To-do")
        }
        #if DEBUG
        .onAppear {
            if let name = DebugLaunchOptions.string("FolioTodoFilter"),
               let category = store.categories().first(where: { $0.name == name }) { model.filter = [category.id] }
        }
        #endif
        .sheet(item: $editing) { task in TaskComposerSheet(task: task, day: nil) }
        .confirmationDialog("Move to", isPresented: isRescheduling, titleVisibility: .visible, presenting: rescheduling) { task in
            Button("Today") { store.reschedule(task, to: today, minutesFromMidnight: task.minutesFromMidnight) }
            Button("Tomorrow") { store.reschedule(task, to: today.adding(days: 1), minutesFromMidnight: task.minutesFromMidnight) }
            Button("Next week") { store.reschedule(task, to: today.adding(days: 7), minutesFromMidnight: task.minutesFromMidnight) }
            Button("Pick a date…") { editing = task }
            if task.dayKey != nil { Button("Remove date", role: .destructive) { store.reschedule(task, to: nil) } }
        }
        .confirmationDialog("Delete this task?", isPresented: isConfirmingDelete, titleVisibility: .visible, presenting: confirmingDelete) { task in
            Button("Delete", role: .destructive) { store.delete(task) }
        } message: { _ in
            Text("Its notes are deleted too.")
        }
        .folioHaptic(.warning, trigger: confirmingDelete?.id)
    }

    /// Toast, then the full-width quick-add bar over a soft scrim (owner review, Batch B):
    /// the page colour fades in over 60 pt so rows don't show through behind the bar.
    private var bottomBar: some View {
        VStack(spacing: Spacing.s) {
            ToastSlot(center: toasts)
                .padding(.horizontal, Spacing.sideMargin)
            TodoQuickAddBar { title, day in request?.send(.task(day, title: title)) }
                .background(alignment: .bottom) {
                    VStack(spacing: 0) {
                        LinearGradient(colors: [.bg.opacity(0), .bg], startPoint: .top, endPoint: .bottom)
                            .frame(height: Self.scrimFade)
                        Rectangle().fill(.bg)
                    }
                    .padding(.top, -Self.scrimFade)
                    .ignoresSafeArea(edges: .bottom)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
        }
    }

    private static let scrimFade: Double = 60

    private func row(_ task: TaskItem, colors: [UUID: Color], today: DayKey) -> some View {
        TodoRow(task: task, isTicked: model.isTicked(task), tint: task.categoryID.flatMap { colors[$0] } ?? .ink,
                today: today, calendar: store.calendar) { toggle(task) }
            .listRowBackground(Rectangle().fill(.bgElevated.opacity(0.55)))
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button(task.isCompleted ? "Not done" : "Done", systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark") {
                    toggle(task)
                }
                .tint(task.isCompleted ? .inkSecondary : .done)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button("Delete", systemImage: "trash", role: .destructive) { delete(task) }
                Button("Edit", systemImage: "pencil") { editing = task }.tint(.indigo)
                Button("Date", systemImage: "calendar") { rescheduling = task }.tint(.ember)
            }
            .contextMenu {
                Button("Edit", systemImage: "pencil") { editing = task }
                Button("Date", systemImage: "calendar") { rescheduling = task }
                Button("Delete", systemImage: "trash", role: .destructive) { delete(task) }
            }
    }

    /// The Undo toast appears as soon as a task is ticked and lasts 4 s, covering both the
    /// 1.2 s pause and the move to Completed (SPEC §6.7).
    private func toggle(_ task: TaskItem) {
        guard model.toggle(task, store: store) else { return }
        toasts.show(ToastMessage(text: "Task done", systemImage: "checkmark.circle.fill", undo: ToastUndo {
            model.undo(task, store: store)
        }))
    }

    /// Tasks with notes ask first; plain tasks delete straight away (SPEC §6.7).
    private func delete(_ task: TaskItem) {
        if let notes = task.notes, !notes.isEmpty { confirmingDelete = task } else { store.delete(task) }
    }

    private func move(_ undated: [TaskItem], indices: IndexSet, offset: Int) {
        var reordered = undated
        reordered.move(fromOffsets: indices, toOffset: offset)
        store.reorderTasks(reordered)
    }

    private var isRescheduling: Binding<Bool> {
        Binding(get: { rescheduling != nil }, set: { if !$0 { rescheduling = nil } })
    }

    private var isConfirmingDelete: Binding<Bool> {
        Binding(get: { confirmingDelete != nil }, set: { if !$0 { confirmingDelete = nil } })
    }
}

#Preview {
    TodoScreen()
        .environment(PreviewData.previewStore())
        .environment(ToastCenter())
}
