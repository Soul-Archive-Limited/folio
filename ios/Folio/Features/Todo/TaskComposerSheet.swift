import SwiftUI

/// New or edit task (SPEC §6.8): title (required), notes, optional date and time, category.
/// Existing tasks get a Delete button at the bottom.
struct TaskComposerSheet: View {
    let task: TaskItem?

    @Environment(DiaryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var notes: String
    @State private var hasDate: Bool
    @State private var day: DayKey
    @State private var minutes: Int?
    @State private var categoryID: UUID?
    @State private var confirmsDelete = false
    @State private var saveCount = 0
    @State private var detent: PresentationDetent = .medium
    @State private var scroll = ScrollPosition(edge: .top)
    @FocusState private var focus: Field?

    private enum Field { case title, notes }

    init(task: TaskItem?, day: DayKey?, title: String = "", categoryID: UUID? = nil) {
        self.task = task
        _title = State(initialValue: task?.title ?? title)
        _notes = State(initialValue: task?.notes ?? "")
        _hasDate = State(initialValue: task?.dayKey != nil || day != nil)
        _day = State(initialValue: task?.day ?? day ?? DayKey(date: AppClock.now, calendar: .current))
        _minutes = State(initialValue: task?.minutesFromMidnight)
        _categoryID = State(initialValue: task?.categoryID ?? categoryID)
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
                        .tint(.ember)
                    if hasDate {
                        ComposerDatePicker(day: $day, minutes: $minutes)
                            .listRowInsets(EdgeInsets())
                    }
                }
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
                        Button("Delete task", role: .destructive) { confirmsDelete = true }
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
            .onChange(of: day) { withAnimation(.smooth(duration: 0.35)) { focus = nil } }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle(task == nil ? "New task" : "Edit task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .buttonStyle(.glassProminent)
                        .tint(.ember)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .presentationBackground(.thickMaterial)
        .privacyCovered()
        .onAppear { if task == nil { focus = .title } }
        .confirmationDialog("Delete this task?", isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: delete)
        }
        .folioHaptic(.warning, trigger: confirmsDelete)
        .folioHaptic(.success, trigger: saveCount)
    }


    private func revealDatePicker() {
        withAnimation(.smooth(duration: 0.35)) {
            focus = nil
            detent = .large
        }
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            withAnimation(.smooth(duration: 0.35)) { scroll.scrollTo(edge: .top) }
        }
    }

    private func save() {
        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if let task {
                try store.updateTask(task, title: title, notes: cleanNotes.isEmpty ? nil : cleanNotes,
                                     day: hasDate ? day : nil, minutesFromMidnight: minutes, categoryID: categoryID)
            } else {
                try store.createTask(title: title, notes: cleanNotes.isEmpty ? nil : cleanNotes,
                                     day: hasDate ? day : nil, minutesFromMidnight: hasDate ? minutes : nil, categoryID: categoryID)
            }
            saveCount += 1
            dismiss()
        } catch {
            // Validation is reflected in the disabled Save button; nothing else to show.
        }
    }

    private func delete() {
        if let task { store.delete(task) }
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
