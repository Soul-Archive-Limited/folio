import SwiftUI

/// New or edit task (SPEC §6.8): title (required), notes, optional date and time, reminder,
/// repeat, subtasks (Batch I), category. Existing tasks get a Delete button at the bottom.
struct TaskComposerSheet: View {
    let task: TaskItem?

    @Environment(DiaryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(ToastCenter.self) private var toasts: ToastCenter?
    @State private var title: String
    @State private var notes: String
    @State private var hasDate: Bool
    @State private var day: DayKey
    @State private var minutes: Int?
    @State private var categoryID: UUID?
    @State private var remindOn: Bool
    @State private var remindTime: Date
    @State private var repeatRule: RepeatRule?
    @State private var subtasks: [TaskSubtasksSection.SubtaskDraft] = []
    @State private var saveCount = 0
    @State private var detent: PresentationDetent = .medium
    @State private var scroll = ScrollPosition(edge: .top)
    @FocusState private var focus: Field?

    private enum Field { case title, notes }

    init(task: TaskItem?, day: DayKey?, title: String = "", minutes: Int? = nil, categoryID: UUID? = nil) {
        self.task = task
        _title = State(initialValue: task?.title ?? title)
        _notes = State(initialValue: task?.notes ?? "")
        _hasDate = State(initialValue: task?.dayKey != nil || day != nil)
        _day = State(initialValue: task?.day ?? day ?? DayKey(date: AppClock.now, calendar: .current))
        _minutes = State(initialValue: task?.minutesFromMidnight ?? minutes)
        _categoryID = State(initialValue: task?.categoryID ?? categoryID)
        let reminder = ReminderTime(rawValue: task?.remindAt)
        _remindOn = State(initialValue: reminder != nil)
        let startDay = task?.day ?? day ?? DayKey(date: AppClock.now, calendar: .current)
        let defaultTime = ReminderTime(day: startDay, minutes: task?.minutesFromMidnight ?? minutes ?? 9 * 60)
        _remindTime = State(initialValue: (reminder ?? defaultTime).date(in: .current) ?? AppClock.now)
        _repeatRule = State(initialValue: RepeatRule.decode(task?.repeatRule))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title, axis: .vertical)
                        .folioFont(.headline)
                        .focused($focus, equals: .title)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...6)
                        .focused($focus, equals: .notes)
                }
                Section {
                    Toggle("Date", isOn: $hasDate.animation())
                        .tint(.emberStrong)
                    if hasDate {
                        ComposerDatePicker(day: $day, minutes: $minutes)
                            .listRowInsets(EdgeInsets())
                    }
                }
                TaskReminderSection(isOn: $remindOn, time: $remindTime, taskMoment: taskMoment)
                TaskRepeatSection(rule: $repeatRule)
                TaskSubtasksSection(items: $subtasks)
                // The chips live in the header, not a row: a row sits on the section's
                // panel, which showed as a faint band behind the glass (owner review, Batch C).
                Section {
                } header: {
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        Text("Category")
                        ComposerCategoryRow(selection: $categoryID)
                            .textCase(nil)
                            .padding(.horizontal, -Spacing.m)
                    }
                }
                if task != nil {
                    Section {
                        Button("Delete task", role: .destructive, action: delete)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .scrollPosition($scroll)
            // Turning on Date or Time puts the keyboard away, raises the sheet and scrolls the
            // form back to its start, so Title stays visible above the picker instead of being
            // half-clipped under the sheet header (owner review, Batches B and C).
            .onChange(of: hasDate) { _, isOn in if isOn { revealDatePicker() } }
            .onChange(of: minutes == nil) { _, noTime in if !noTime { revealDatePicker() } }
            // When a date is already on at open, picking a day or scrolling also puts the
            // keyboard away.
            .onChange(of: day) { withAnimation(FolioMotion.standard()) { focus = nil } }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle(task == nil ? "New task" : "Edit task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .buttonStyle(.glassProminent)
                        .tint(.emberStrong)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .presentationBackground(.thickMaterial)
        .privacyCovered()
        .onAppear {
            if task == nil { focus = .title }
            if let task {
                subtasks = store.subtasks(of: task).map { .init(id: $0.id, title: $0.title, isDone: $0.isCompleted, storedID: $0.id) }
            }
        }
        .folioHaptic(.success, trigger: saveCount)
    }


    private func revealDatePicker() {
        withAnimation(FolioMotion.standard()) {
            focus = nil
            detent = .large
        }
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            withAnimation(FolioMotion.standard()) { scroll.scrollTo(edge: .top) }
        }
    }

    /// The task's own date and time, offered as the reminder time.
    private var taskMoment: Date? {
        guard hasDate, let minutes else { return nil }
        return ReminderTime(day: day, minutes: minutes).date(in: .current)
    }

    private func save() {
        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let saved: TaskItem
            if let task {
                try store.updateTask(task, title: title, notes: cleanNotes.isEmpty ? nil : cleanNotes,
                                     day: hasDate ? day : nil, minutesFromMidnight: minutes, categoryID: categoryID)
                saved = task
            } else {
                saved = try store.createTask(title: title, notes: cleanNotes.isEmpty ? nil : cleanNotes,
                                             day: hasDate ? day : nil, minutesFromMidnight: hasDate ? minutes : nil, categoryID: categoryID)
            }
            store.setReminder(saved, remindOn ? ReminderTime(date: remindTime, calendar: .current) : nil)
            store.setRepeat(saved, repeatRule)
            saveSubtasks(of: saved)
            saveCount += 1
            dismiss()
        } catch {
            // Validation is reflected in the disabled Save button; nothing else to show.
        }
    }

    /// Adds new subtasks, renames and ticks existing ones, and sends removed ones to Recently Deleted.
    private func saveSubtasks(of parent: TaskItem) {
        let stored = store.subtasks(of: parent)
        let kept = Set(subtasks.compactMap(\.storedID))
        for old in stored where !kept.contains(old.id) { store.trash(old) }
        for draft in subtasks {
            let clean = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { continue }
            if let id = draft.storedID, let existing = stored.first(where: { $0.id == id }) {
                if existing.title != clean {
                    try? store.updateTask(existing, title: clean, notes: existing.notes, day: parent.day,
                                          minutesFromMidnight: nil, categoryID: existing.categoryID)
                }
                if existing.isCompleted != draft.isDone { store.setCompleted(existing, draft.isDone) }
            } else if let created = try? store.addSubtask(title: clean, to: parent), draft.isDone {
                store.setCompleted(created, true)
            }
        }
    }

    /// To Recently Deleted, with Undo (SPEC §5.2).
    private func delete() {
        if let task {
            store.trash(task)
            toasts?.show(.movedToTrash { store.restoreFromTrash(task) })
        }
        dismiss()
    }
}

#if DEBUG
#Preview {
    Color.bg.sheet(isPresented: .constant(true)) {
        TaskComposerSheet(task: nil, day: DayKey(date: .now, calendar: .current))
    }
    .environment(PreviewData.previewStore())
}
#endif
