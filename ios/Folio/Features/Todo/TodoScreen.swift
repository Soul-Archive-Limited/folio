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
    @State private var showsTrash = false
    @State private var tabBar: TabBarShape?
    @State private var isScrolling = false
    @State private var isTyping = false
    @State private var quickAddHeight: Double = 48
    @State private var rejectedMoves = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let today = store.today
        let sections = model.sections(from: store.allTasks(), today: today)
        let colors = Dictionary(uniqueKeysWithValues: store.categories().map { ($0.id, $0.color.color) })
        NavigationStack {
            List {
                Section {} header: {
                    // A header, not a row: rows sit on the section's panel, which showed as a
                    // band behind the glass chips.
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        CompactTitleText(title: "To-do")
                        CategoryFilterBar(selection: $model.filter)
                            .padding(.horizontal, -Spacing.sideMargin - Spacing.m)
                    }
                    .textCase(nil)
                    .padding(.bottom, Spacing.xxs)
                }
                if sections.active.isEmpty {
                    Section {
                        EmptyStateView(systemImage: "checkmark.seal", message: "All clear.")
                            .frame(maxWidth: .infinity)
                            .listRowBackground(Color.clear)
                    }
                }
                ForEach(sections.visibleGroups) { group in
                    let tasks = sections.groups[group] ?? []
                    Section {
                        if !model.foldedGroups.contains(group) {
                            ForEach(tasks) { task in
                                row(task, colors: colors, today: today)
                            }
                            .onMove { indices, offset in move(tasks, indices: indices, offset: offset) }
                        }
                    } header: {
                        TodoGroupHeader(title: group.title, count: tasks.count, isOverdue: group == .overdue,
                                        isExpanded: !model.foldedGroups.contains(group)) {
                            withAnimation(FolioMotion.standard(reduceMotion: reduceMotion)) { model.toggleFold(group) }
                        }
                    }
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
                if store.trashCount > 0 {
                    Section {
                        RecentlyDeletedLink(count: store.trashCount) { showsTrash = true }
                            .listRowBackground(Color.clear)
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
            .onScrollPhaseChange { _, phase in isScrolling = phase.isScrolling }
            // Scrolling or tapping anywhere outside the quick-add bar puts the keyboard away (Batch I).
            .scrollDismissesKeyboard(.immediately)
            .simultaneousGesture(TapGesture().onEnded { KeyboardDismissal.dismiss() }, including: isTyping ? .all : .subviews)
            .background {
                TabBarShapeReader(isTracking: isScrolling) { tabBar = $0 }
                    .accessibilityHidden(true)
            }
            .animation(FolioMotion.standard(), value: sections.active.map(\.id))
            .animation(FolioMotion.standard(), value: sections.completed.map(\.id))
            .compactTitle("To-do")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    TodoDateFilterButton(day: $model.dayFilter, today: today)
                }
            }
            // To-do's own toast slot lives in the root list's bottom bar, so the pushed screen
            // hosts its own.
            .navigationDestination(isPresented: $showsTrash) { RecentlyDeletedView().toastHost(toasts) }
        }
        #if DEBUG
        .onAppear {
            if let name = DebugLaunchOptions.string("FolioTodoFilter"),
               let category = store.categories().first(where: { $0.name == name }) { model.filter = [category.id] }
            if DebugLaunchOptions.string("FolioOpen") == "editTask" {
                editing = store.allTasks().first { store.subtaskProgress(of: $0) != nil }
            }
        }
        #endif
        .sheet(item: $editing) { task in TaskComposerSheet(task: task, day: nil) }
        .folioHaptic(.warning, trigger: rejectedMoves)
        .confirmationDialog("Move to", isPresented: isRescheduling, titleVisibility: .visible, presenting: rescheduling) { task in
            Button("Today") { store.reschedule(task, to: today, minutesFromMidnight: task.minutesFromMidnight) }
            Button("Tomorrow") { store.reschedule(task, to: today.adding(days: 1), minutesFromMidnight: task.minutesFromMidnight) }
            Button("Next week") { store.reschedule(task, to: today.adding(days: 7), minutesFromMidnight: task.minutesFromMidnight) }
            Button("Pick a date…") { editing = task }
            if task.dayKey != nil { Button("Remove date", role: .destructive) { store.reschedule(task, to: nil) } }
        }
    }

    /// Toast, then the full-width quick-add bar over a soft scrim (owner review, Batch B):
    /// the page colour fades in over 60 pt so rows don't show through behind the bar.
    /// When the tab bar minimises, the bar drops into the tab bar's row beside the small
    /// circle, so there's never a gap under it (owner review, Batch C).
    private var bottomBar: some View {
        let inline = inlinePlacement
        let barPadding = Spacing.s // read here: the geometry closure below is Sendable
        return VStack(spacing: Spacing.s) {
            ToastSlot(center: toasts)
                .padding(.horizontal, Spacing.sideMargin)
            TodoQuickAddBar(leadingInset: inline?.leading ?? Spacing.sideMargin,
                            onFocusChange: { isTyping = $0 }) { parsed in
                request?.send(.task(parsed.day, title: parsed.title, minutes: parsed.minutesFromMidnight))
            }
            .onGeometryChange(for: Double.self) { $0.size.height - barPadding } action: { quickAddHeight = $0 }
        }
        // A negative bottom padding shrinks the inset too, so the list's last row follows the bar down.
        .padding(.bottom, -(inline?.drop ?? 0))
        .animation(FolioMotion.standard(reduceMotion: reduceMotion), value: inline)
        // The scrim sits behind the toast too, so rows fade out under it rather than show
        // through (owner review, Batch B: toasts never overlap rows).
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
        .animation(FolioMotion.toast(), value: toasts.current)
    }

    private static let scrimFade: Double = 60

    /// Where the quick-add bar goes while the tab bar is minimised: down by `drop` so it's
    /// centred on the small circle, and in from the leading edge past it. Not while typing:
    /// the keyboard covers the tab bar, and the bar rides above the keyboard.
    private var inlinePlacement: InlinePlacement? {
        guard let tabBar, tabBar.isMinimised, !isTyping else { return nil }
        let restingMidY = tabBar.top - Spacing.s - quickAddHeight / 2
        let drop = tabBar.platter.midY - restingMidY
        guard drop > 0 else { return nil }
        return InlinePlacement(drop: drop, leading: tabBar.platter.maxX + Spacing.xs)
    }

    private struct InlinePlacement: Equatable {
        var drop: Double
        var leading: Double
    }

    private func row(_ task: TaskItem, colors: [UUID: Color], today: DayKey) -> some View {
        TodoRow(task: task, isTicked: model.isTicked(task), tint: task.categoryID.flatMap { colors[$0] } ?? .ink,
                today: today, calendar: store.calendar) { toggle(task) }
            // A tap opens the task; a long press keeps the menu (Batch I).
            .onTapGesture { editing = task }
            .accessibilityAction(named: "Edit") { editing = task }
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
                Button("Date", systemImage: "calendar") { rescheduling = task }.tint(.emberStrong)
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

    /// Moves the task to Recently Deleted straight away, with Undo (SPEC §5.2).
    private func delete(_ task: TaskItem) {
        store.trash(task)
        toasts.show(.movedToTrash { store.restoreFromTrash(task) })
    }

    /// Drag to reorder among tasks on the same date; a drop onto another date springs back.
    private func move(_ tasks: [TaskItem], indices: IndexSet, offset: Int) {
        guard let reordered = TodoModel.reorder(tasks, from: indices, to: offset) else {
            rejectedMoves += 1
            return
        }
        store.reorderTasks(reordered)
    }

    private var isRescheduling: Binding<Bool> {
        Binding(get: { rescheduling != nil }, set: { if !$0 { rescheduling = nil } })
    }
}

#if DEBUG
#Preview {
    TodoScreen()
        .environment(PreviewData.previewStore())
        .environment(ToastCenter())
}
#endif
