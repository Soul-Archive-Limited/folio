import SwiftUI

/// What the ✦ menu asked for (SPEC §6.12).
enum WritingTool: String, Identifiable {
    case titles, polish, tasks
    var id: String { rawValue }
}

/// The preview for a ✦ tool: three title chips, a grammar diff, or tasks to tick. Nothing
/// changes the entry until the user accepts.
struct WritingToolsSheet: View {
    let tool: WritingTool
    @Bindable var model: ComposerModel
    let assistant: WritingAssistant

    @Environment(DiaryStore.self) private var store
    @Environment(ToastCenter.self) private var toasts
    @Environment(\.dismiss) private var dismiss
    @Environment(\.fontResolutionContext) private var fontContext

    @State private var titles: [String] = []
    @State private var polished: String?
    @State private var original = ""
    @State private var tasks: [FoundTask] = []
    @State private var error: WritingAssistant.AssistantError?
    @State private var isLoading = true

    struct FoundTask: Identifiable {
        let id = UUID()
        let title: String
        var isOn = true
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: Spacing.m) {
                        ProgressView()
                        Text("Working on your iPhone…").folioFont(.callout).foregroundStyle(.inkSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error {
                    EmptyStateView(systemImage: "sparkles", message: LocalizedStringKey(error.message))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    content
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(.thickMaterial)
        .privacyCovered()
        .task { await load() }
        .onDisappear { assistant.cancel() }
    }

    @ViewBuilder private var content: some View {
        switch tool {
        case .titles:
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("Tap one to use it.").folioFont(.callout).foregroundStyle(.inkSecondary)
                ForEach(titles, id: \.self) { suggestion in
                    Button {
                        model.title = suggestion
                        dismiss()
                    } label: {
                        Text(suggestion)
                            .folioFont(.headline)
                            .foregroundStyle(.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Spacing.m)
                            .folioGlass(in: .rect(cornerRadius: Radius.card), interactive: true)
                    }
                    .buttonStyle(.pressable)
                }
                Spacer()
            }
            .padding(Spacing.sideMargin)
        case .polish:
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    if polished == original {
                        Text("Nothing to fix. It reads well as it is.").folioFont(.callout).foregroundStyle(.inkSecondary)
                    } else {
                        Text("Removed words are struck through. New words are underlined.")
                            .font(.footnote).foregroundStyle(.inkSecondary)
                        Text(PolishPreview.attributed(from: original, to: polished ?? original))
                            .font(model.writingFont.font())
                            .lineSpacing(5)
                            .textSelection(.enabled)
                            // VoiceOver reads the suggested version rather than the markup.
                            .accessibilityLabel(Text("Suggested version: \(WordDiff.plain(polished ?? original))"))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.sideMargin)
            }
        case .tasks:
            if tasks.isEmpty {
                EmptyStateView(systemImage: "checklist", message: "No tasks in this entry.")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section {
                        ForEach($tasks) { $task in
                            Toggle(isOn: $task.isOn) { Text(task.title).folioFont(.body) }
                                .toggleStyle(.switch)
                                .tint(.emberStrong)
                        }
                    } footer: {
                        Text("Ticked tasks are added to \(model.day.startDate(in: store.calendar).formatted(.dateTime.weekday(.wide).day().month(.wide))).")
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(tool == .titles ? "Close" : "Discard", systemImage: "xmark") { dismiss() }
        }
        if !isLoading, error == nil {
            if tool == .polish, let polished, polished != original {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Accept") {
                        model.body = RichTextBridge.attributedString(fromMarkdown: polished, writingFont: model.writingFont)
                        dismiss()
                    }
                    .buttonStyle(.glassProminent).tint(.emberStrong)
                }
            }
            if tool == .tasks, tasks.contains(where: \.isOn) {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add \(tasks.count { $0.isOn })", action: addTasks)
                        .buttonStyle(.glassProminent).tint(.emberStrong)
                }
            }
        }
    }

    private var title: LocalizedStringKey {
        switch tool {
        case .titles: "Suggested titles"
        case .polish: "Polish grammar"
        case .tasks: "Tasks in this entry"
        }
    }

    private func load() async {
        original = RichTextBridge.markdown(from: model.body, context: fontContext, writingFont: model.writingFont)
        let text = tool == .titles && !model.title.isEmpty ? "\(model.title)\n\n\(original)" : original
        do {
            switch tool {
            case .titles: titles = try await assistant.suggestTitles(for: text)
            case .polish: polished = try await assistant.polish(text)
            case .tasks: tasks = try await assistant.findTasks(in: text).map { FoundTask(title: $0) }
            }
        } catch let failure {
            error = failure
        }
        isLoading = false
    }

    private func addTasks() {
        let chosen = tasks.filter(\.isOn)
        for task in chosen { _ = try? store.createTask(title: String(task.title.prefix(TaskItem.titleLengths.upperBound)), day: model.day) }
        toasts.show(ToastMessage(text: chosen.count == 1 ? "1 task added" : "\(chosen.count) tasks added", systemImage: "checklist"))
        dismiss()
    }
}

/// Builds the diff text: removed words struck through and faded, new words underlined.
enum PolishPreview {
    static func attributed(from old: String, to new: String) -> AttributedString {
        var result = AttributedString()
        for change in WordDiff.changes(from: WordDiff.plain(old), to: WordDiff.plain(new)) {
            switch change {
            case .same(let text):
                result += AttributedString(text)
            case .removed(let text):
                var part = AttributedString(text)
                part.strikethroughStyle = .single
                part.foregroundColor = .inkTertiary
                result += part
            case .added(let text):
                var part = AttributedString(text)
                part.underlineStyle = .single
                part.foregroundColor = .ember
                result += part
            }
        }
        return result
    }
}

/// The ✦ button: a glass menu of the three tools. Shown only when Apple's on-device model
/// is available (SPEC §9).
struct WritingToolsMenu: View {
    let onPick: (WritingTool) -> Void

    var body: some View {
        Menu {
            Button("Suggest a title", systemImage: "textformat.size") { onPick(.titles) }
            Button("Polish grammar", systemImage: "text.badge.checkmark") { onPick(.polish) }
            Button("Find tasks", systemImage: "checklist") { onPick(.tasks) }
        } label: {
            Label("Writing tools", systemImage: "sparkles")
                .frame(width: Spacing.minHitTarget, height: Spacing.minHitTarget)
        }
        .accessibilityInputLabels(["Writing tools", "Sparkles", "Intelligence"])
    }
}
