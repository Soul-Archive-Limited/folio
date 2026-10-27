import SwiftUI
import TipKit

/// The guided tour (SPEC §6.15): TipKit popover tips, one at a time, each advancing on the
/// user's action rather than a timer. Every tip offers "Skip tour", and once invalidated a
/// tip never comes back unless the tour is replayed from Profile → Help.
nonisolated enum TourAction {
    static let next = "next"
    static let skip = "skip"
    static let done = "done"

    static var skipAction: Tips.Action { Tips.Action(id: skip, title: String(localized: "Skip tour")) }
}

/// 1. The month grid.
nonisolated struct MonthGridTip: Tip {
    /// The tour runs only while this is on: after onboarding and its greeting, or on replay.
    @Parameter static var tourActive: Bool = false

    var title: Text { Text("Your month") }
    var message: Text? { Text("Days you write on get a photo or a dot.") }
    var rules: [Rule] { #Rule(Self.$tourActive) { $0 } }
    var actions: [Action] {
        Action(id: TourAction.next, title: String(localized: "Next"))
        TourAction.skipAction
    }
}

/// 2. Today's cell; advances when a day is tapped.
nonisolated struct TapDayTip: Tip {
    var title: Text { Text("Tap a day") }
    var message: Text? { Text("Tap a day to see its pages and tasks.") }
    var rules: [Rule] { #Rule(MonthGridTip.$tourActive) { $0 } }
    var actions: [Action] { TourAction.skipAction }
}

/// 3. The floating "+"; advances when the composer opens.
nonisolated struct AddEntryTip: Tip {
    var title: Text { Text("Write your first page") }
    var message: Text? { Text("The calendar stays above while you type.") }
    var rules: [Rule] { #Rule(MonthGridTip.$tourActive) { $0 } }
    var actions: [Action] { TourAction.skipAction }
}

/// 3b. Inside the composer, pointing at the photo, category and dictation tools.
nonisolated struct ComposerToolsTip: Tip {
    var title: Text { Text("Photos, categories, your voice") }
    var message: Text? { Text("Add photos, pick a category, or dictate instead of typing.") }
    var rules: [Rule] { #Rule(MonthGridTip.$tourActive) { $0 } }
    var actions: [Action] {
        Action(id: TourAction.done, title: String(localized: "Got it"))
        TourAction.skipAction
    }
}

/// 4. The To-do tab; advances when it's opened.
nonisolated struct TodoTabTip: Tip {
    var title: Text { Text("To-do") }
    var message: Text? { Text("Tasks you finish stay on their day, ticked.") }
    var rules: [Rule] { #Rule(MonthGridTip.$tourActive) { $0 } }
    var actions: [Action] { TourAction.skipAction }
}

/// 5. The Profile tab; the last tip. Guests also hear about sync, once sign-in exists.
nonisolated struct ProfileTabTip: Tip {
    var title: Text { Text("Make it yours") }
    var message: Text? {
        FeatureFlags.showsSignIn
            ? Text("Make categories with your own colours. Turn on sync any time.")
            : Text("Make categories with your own colours.")
    }
    var rules: [Rule] { #Rule(MonthGridTip.$tourActive) { $0 } }
    var actions: [Action] { TourAction.skipAction }
}
