import SwiftUI

/// Opens the right sheet for a `NewItemRequest`.
struct ComposerRoute: View {
    let request: NewItemRequest
    let calendar: CalendarModel?
    let namespace: Namespace.ID

    @Environment(DiaryStore.self) private var store
    @Environment(ToastCenter.self) private var toasts

    var body: some View {
        switch request {
        case .entry(let day), .dictation(let day):
            ComposerSheet(model: ComposerModel(day: day, categoryID: store.settings().defaultCategoryID,
                                               writingFont: writingFont),
                          calendar: calendar, startsDictation: request == .dictation(day), onSaved: saved)
                .navigationTransition(.zoom(sourceID: FloatingAddButton.transitionID, in: namespace))
        case .editEntry(let id):
            if let entry = store.entry(id: id) {
                ComposerSheet(model: ComposerModel(entry: entry, writingFont: writingFont),
                              calendar: calendar, startsLarge: true, onSaved: saved)
            }
        case .pastEntry:
            ComposerSheet(model: ComposerModel(day: store.today.adding(days: -1), categoryID: store.settings().defaultCategoryID,
                                               writingFont: writingFont),
                          calendar: calendar, opensDatePicker: true, onSaved: saved)
        case .resumeDraft:
            if let model = resumedDraftModel {
                ComposerSheet(model: model, calendar: calendar, startsLarge: model.entryID != nil, onSaved: saved)
            }
        case .task(let day, let title, let minutes):
            TaskComposerSheet(task: nil, day: day, title: title, minutes: minutes, categoryID: store.settings().defaultCategoryID)
        }
    }

    /// The composer for the draft on disk — a new entry or an edit — already restored.
    private var resumedDraftModel: ComposerModel? {
        guard let draft = store.drafts.load(), !draft.isEmpty else { return nil }
        let model: ComposerModel
        if let id = draft.entryID {
            guard let entry = store.entry(id: id) else { return nil }
            model = ComposerModel(entry: entry, writingFont: writingFont)
        } else {
            model = ComposerModel(day: DayKey(rawValue: draft.dayKey) ?? store.today, categoryID: draft.categoryID,
                                  writingFont: writingFont)
        }
        model.restoreDraft()
        return model
    }

    private var writingFont: WritingFont {
        WritingFont(rawValue: store.settings().writingFont) ?? .newYork
    }

    private func saved(_ entry: Entry) {
        toasts.show(ToastMessage(text: "Entry saved"))
    }
}
