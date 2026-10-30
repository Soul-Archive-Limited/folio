import SwiftUI

/// "Remind me" (Batch I): at the task's time or a chosen time. The first time it's turned on, a
/// glass explainer comes before the system's notification prompt (SPEC §7); denied → a gentle
/// way to Settings.
struct TaskReminderSection: View {
    @Binding var isOn: Bool
    @Binding var time: Date
    /// The task's own date and time, when it has both.
    let taskMoment: Date?

    @State private var showsExplainer = false
    @State private var showsDenied = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        Section {
            Toggle(isOn: Binding(get: { isOn }, set: { turnOn($0) })) {
                Label("Remind me", systemImage: "bell")
            }
            .tint(.emberStrong)
            if isOn {
                DatePicker("At", selection: $time, displayedComponents: [.date, .hourAndMinute])
                if let taskMoment, taskMoment != time {
                    Button("At the task's time", systemImage: "clock.arrow.circlepath") { time = taskMoment }
                        .tint(.emberStrong)
                }
            }
        } footer: {
            if isOn { Text("A notification on this iPhone and your other devices. Nothing goes through our server.") }
        }
        .sheet(isPresented: $showsExplainer) {
            PermissionExplainer(systemImage: "bell.badge",
                                message: "Folio can remind you about this task with a notification. Reminders are set on your devices only.",
                                footnote: "iOS will ask next.") {
                showsExplainer = false
                Task {
                    if await ReminderScheduler.shared.requestAccess() { withAnimation { isOn = true } } else { showsDenied = true }
                }
            }
        }
        .alert("Notifications are off for Folio", isPresented: $showsDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
            }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("Turn on notifications for Folio in Settings whenever you'd like reminders.")
        }
    }

    private func turnOn(_ on: Bool) {
        guard on else { withAnimation { isOn = false }; return }
        Task {
            switch await ReminderScheduler.shared.access() {
            case .granted: withAnimation { isOn = true }
            case .needsPrompt: showsExplainer = true
            case .denied: showsDenied = true
            }
        }
    }
}

/// "Repeat": Never, every day / weekday / week / month / year, or every N days, weeks or months.
struct TaskRepeatSection: View {
    @Binding var rule: RepeatRule?

    var body: some View {
        Section {
            Picker(selection: Binding(get: { rule?.frequency }, set: { frequency in
                rule = frequency.map { RepeatRule(frequency: $0, interval: rule?.interval ?? 2, unit: rule?.unit ?? .day) }
            })) {
                Text("Never").tag(RepeatRule.Frequency?.none)
                Text("Every day").tag(RepeatRule.Frequency?.some(.daily))
                Text("Every weekday").tag(RepeatRule.Frequency?.some(.weekdays))
                Text("Every week").tag(RepeatRule.Frequency?.some(.weekly))
                Text("Every month").tag(RepeatRule.Frequency?.some(.monthly))
                Text("Every year").tag(RepeatRule.Frequency?.some(.yearly))
                Text("Custom").tag(RepeatRule.Frequency?.some(.custom))
            } label: {
                Label("Repeat", systemImage: "repeat")
            }
            if let current = rule, current.frequency == .custom {
                Stepper(value: Binding(get: { current.interval }, set: { rule?.interval = $0 }), in: 1...99) {
                    Text(current.label)
                }
                Picker("Unit", selection: Binding(get: { current.unit }, set: { rule?.unit = $0 })) {
                    Text("Days").tag(RepeatRule.Unit.day)
                    Text("Weeks").tag(RepeatRule.Unit.week)
                    Text("Months").tag(RepeatRule.Unit.month)
                }
                .pickerStyle(.segmented)
            }
        } footer: {
            if rule != nil { Text("Ticking it keeps it done on its day and adds the next one.") }
        }
    }
}

/// Subtasks: tick in place, add with Return, swipe to remove. New tasks keep them in the sheet
/// until Save.
struct TaskSubtasksSection: View {
    @Binding var items: [SubtaskDraft]

    @State private var newTitle = ""
    @FocusState private var adding: Bool

    struct SubtaskDraft: Identifiable, Equatable {
        let id: UUID
        var title: String
        var isDone: Bool
        /// The stored subtask, or nil until saved.
        var storedID: UUID?
    }

    var body: some View {
        Section("Subtasks") {
            ForEach($items) { $item in
                HStack(spacing: Spacing.s) {
                    TaskCheckbox(isOn: item.isDone, tint: .ink) { item.isDone.toggle() }
                    TextField("Subtask", text: $item.title)
                        .strikethrough(item.isDone)
                        .foregroundStyle(item.isDone ? .inkSecondary : .ink)
                }
            }
            .onDelete { items.remove(atOffsets: $0) }
            HStack(spacing: Spacing.s) {
                Image(systemName: "plus.circle").foregroundStyle(.ember).accessibilityHidden(true)
                TextField("Add a subtask", text: $newTitle)
                    .focused($adding)
                    .submitLabel(.next)
                    .onSubmit(add)
            }
        }
    }

    private func add() {
        let clean = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        items.append(SubtaskDraft(id: UUID(), title: clean, isDone: false, storedID: nil))
        newTitle = ""
        adding = true
    }
}
