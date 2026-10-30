import SwiftUI

/// The composer half sheet (SPEC §6.4). The calendar stays visible and tappable above it at
/// the medium detent; tapping another day moves the entry there.
struct ComposerSheet: View {
    @State private var model: ComposerModel
    let calendar: CalendarModel?
    var startsLarge = false
    var opensDatePicker = false
    /// "Dictate an entry" (long-press "+"): opens listening (SPEC §8).
    var startsDictation = false
    let onSaved: (Entry) -> Void

    @Environment(DiaryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.fontResolutionContext) private var fontContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var detent: PresentationDetent = .medium
    @State private var confirmsDiscard = false
    /// Set by the dialog's Discard button; the sheet is dismissed once the dialog is gone.
    @State private var discardsAfterDialog = false
    @State private var errorMessage: String?
    @State private var saveCount = 0
    @FocusState private var focus: Field?
    @State private var dictation = DictationController()
    @State private var assistant = WritingAssistant()
    @State private var writingTool: WritingTool?
    /// What was just dictated, while the "Tidy punctuation" offer shows (Batch I).
    @State private var tidyOffer: String?
    @Environment(TourModel.self) private var tour: TourModel?

    enum Field { case title, body }

    init(model: ComposerModel, calendar: CalendarModel?, startsLarge: Bool = false, opensDatePicker: Bool = false,
         startsDictation: Bool = false, onSaved: @escaping (Entry) -> Void) {
        self.startsDictation = startsDictation
        _model = State(initialValue: model)
        self.calendar = calendar
        self.startsLarge = startsLarge
        self.opensDatePicker = opensDatePicker
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.s) {
                TextField("Title", text: $model.title, axis: .vertical)
                    .folioFont(.title2)
                    .focused($focus, equals: .title)
                    .submitLabel(.next)
                    .onSubmit { focus = .body }
                if !model.photos.isEmpty || model.isProcessingPhotos {
                    ComposerPhotoStrip(model: model)
                }
                ComposerCategoryRow(selection: $model.categoryID)
                ComposerBodyEditor(model: model, placeholder: placeholder)
                    .focused($focus, equals: .body)
            }
            .padding(.horizontal, Spacing.sideMargin)
            .padding(.top, Spacing.xs)
            .toolbar { toolbar }
            .safeAreaInset(edge: .bottom) { bottomBar }
            .animation(reduceMotion ? FolioMotion.reduced : .spring(duration: 0.4, bounce: 0.2), value: dictation.isVisible)
            .navigationBarTitleDisplayMode(.inline)
        }
        .tourHost(.composer, tour)
        .onChange(of: model.hasChanges) { _, changed in tour?.composerChanged(hasChanges: changed) }
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        .presentationDragIndicator(.visible)
        // Clearly a layer: a solid-leaning material with a top highlight, and the screen behind
        // dims (MainTabView) — before Batch I the sheet and the calendar looked the same.
        .presentationBackground { SheetSurface() }
        .interactiveDismissDisabled(model.hasChanges)
        .privacyCovered()
        // Editing a saved entry only throws away the changes; a new entry goes entirely.
        .confirmationDialog(model.isNew ? "Discard this entry?" : "Discard changes?",
                            isPresented: $confirmsDiscard, titleVisibility: .visible) {
            Button(model.isNew ? "Discard" : "Discard changes", role: .destructive) { discardsAfterDialog = true }
            Button(model.isNew ? "Keep writing" : "Keep editing", role: .cancel) {}
        }
        // Dismissing the sheet from inside the dialog's action ran two dismissals at once; UIKit
        // then left the screen under a large sheet scaled away (blank) until the next touch
        // (owner's test, Batch I). Dismiss after the dialog has finished closing.
        .onChange(of: confirmsDiscard) { _, showing in
            if !showing, discardsAfterDialog {
                discardsAfterDialog = false
                discard()
            }
        }
        .alert("Continue your draft?", isPresented: hasPendingDraft) {
            Button("Continue", action: model.restoreDraft)
            Button("Discard draft", role: .destructive, action: model.discardDraft)
        } message: {
            Text("You have unsaved writing from earlier.")
        }
        .alert("Couldn't save", isPresented: hasError) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "")
        }
        .folioHaptic(.warning, trigger: confirmsDiscard)
        .folioHaptic(.success, trigger: saveCount)
        .onChange(of: calendar?.selectedDay) { _, newDay in
            if let newDay, newDay != model.day { model.day = newDay }
        }
        .onAppear(perform: appear)
        .onChange(of: dictation.isVisible) { _, visible in
            let heard = dictation.session.sessionText
            // Offer the on-device tidy-up only when Apple's model is here and there's a sentence's worth.
            if !visible, assistant.availability == .available, heard.split(separator: " ").count >= 3 { tidyOffer = heard }
            if visible { tidyOffer = nil }
        }
        .task { await dictation.checkSupport() }
        .onChange(of: focus) { _, field in if field == .body { model.hasPlacedCursor = true } }
        .dictationPermissions(dictation)
        .sheet(item: $writingTool) { tool in
            WritingToolsSheet(tool: tool, model: model, assistant: assistant)
        }
        .onDisappear {
            model.writeDraftIfNeeded(context: fontContext)
            model.stopAutosave()
            Task { await dictation.session.cancel() }
        }
    }

    /// The tool row, or the dictation capsule while listening (SPEC §6.11).
    @ViewBuilder private var bottomBar: some View {
        if let tidyOffer, !dictation.isVisible {
            DictationTidyOffer(text: tidyOffer, model: model, assistant: assistant) { self.tidyOffer = nil }
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        if dictation.isVisible {
            DictationCapsule(session: dictation.session,
                             onDone: { Task { await dictation.session.finish() } },
                             onDismiss: { Task { await dictation.session.cancel() } })
                .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            ComposerToolRow(model: model, onDictate: dictateAction, onWritingTool: writingToolAction)
                .transition(.opacity)
        }
    }

    private var dictateAction: (() -> Void)? {
        guard dictation.isSupported else { return nil }
        return { dictation.micTapped() }
    }

    private var writingToolAction: ((WritingTool) -> Void)? {
        guard assistant.availability == .available else { return nil }
        return { tool in writingTool = tool }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel", systemImage: "xmark", action: cancel)
        }
        ToolbarItem(placement: .principal) {
            ComposerDatePill(day: $model.day, minutes: $model.minutesFromMidnight, opensPickerOnAppear: opensDatePicker)
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save", action: save)
                .buttonStyle(.glassProminent)
                .tint(.emberStrong)
                .disabled(!model.hasContent)
        }
    }

    private var placeholder: LocalizedStringKey {
        model.isPastDay(today: store.today) ? "What do you remember about this day?" : "What happened today?"
    }

    private var hasPendingDraft: Binding<Bool> {
        Binding(get: { model.pendingDraft != nil }, set: { if !$0 { model.pendingDraft = nil } })
    }

    private var hasError: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func appear() {
        if startsLarge { detent = .large }
        model.startAutosave(context: fontContext)
        dictation.session.onCommit = { [model] phrase in model.insertDictation(phrase) }
        dictation.hints = { [store, model] in
            DictationRules.contextualStrings(name: store.settings().displayName, categories: store.categories().map(\.name),
                                             title: model.title)
        }
        if startsDictation { dictation.micTapped() }
        #if DEBUG
        switch DebugLaunchOptions.string("FolioOpenTool") {
        case "mic": dictation.micTapped()
        case "titles": writingTool = .titles
        case "polish": writingTool = .polish
        case "tasks": writingTool = .tasks
        default: break
        }
        #endif
        // No auto-focus: the keyboard would lift the sheet and hide the calendar that's meant
        // to stay visible above it (SPEC §6.4). Tapping the page starts writing.
    }

    private func cancel() {
        if model.hasChanges { confirmsDiscard = true } else { discard() }
    }

    private func discard() {
        Task { await dictation.session.cancel() }
        model.discard()
        dismiss()
    }

    /// Finishes dictation first so the last words heard are part of the entry.
    private func save() {
        guard dictation.session.isRunning else { return commit() }
        Task {
            await dictation.session.finish()
            commit()
        }
    }

    private func commit() {
        do {
            let entry = try model.save(to: store, context: fontContext)
            saveCount += 1
            calendar?.select(model.day, reduceMotion: reduceMotion)
            onSaved(entry)
            dismiss()
        } catch {
            errorMessage = error == .titleTooLong
                ? String(localized: "Titles can be up to 120 characters.")
                : String(localized: "Your entry is still here — try again.")
        }
    }
}

#if DEBUG
#Preview {
    let store = PreviewData.previewStore()
    Color.bg.sheet(isPresented: .constant(true)) {
        ComposerSheet(model: ComposerModel(day: store.today, categoryID: nil, writingFont: .newYork,
                                           drafts: DraftStore(directory: .temporaryDirectory)),
                      calendar: nil, onSaved: { _ in })
    }
    .environment(store)
}
#endif
