import SwiftUI

/// The guided tour's six steps (SPEC §6.15), in order. Look-only steps move on by themselves
/// after a few seconds; action steps move on when the user does the thing (or taps Next).
enum TourStep: Int, CaseIterable, Identifiable, Sendable {
    case month = 1, tapDay, add, composerTools, todo, profile

    var id: Int { rawValue }

    /// Which surface draws the card: the main tab view, or the composer sheet above it.
    enum Host { case main, composer }

    var host: Host { self == .composerTools ? .composer : .main }

    /// Look-only steps advance after `TourModel.autoAdvanceDelay`; action steps wait.
    var isLookOnly: Bool { self != .tapDay && self != .add && self != .profile }

    var tab: AppTab {
        switch self {
        case .month, .tapDay, .add, .composerTools: .calendar
        case .todo: .todo
        case .profile: .profile
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .month: "Your month"
        case .tapDay: "Tap a day"
        case .add: "Write your first page"
        case .composerTools: "Photos, categories, your voice"
        case .todo: "To-do"
        case .profile: "Make it yours"
        }
    }

    var message: LocalizedStringKey {
        switch self {
        case .month: "Days you write on get a photo or a dot."
        case .tapDay: "Tap a day to see its pages and tasks."
        case .add: "Tap + to write. The calendar stays above while you type."
        case .composerTools: "Add photos, pick a category, or dictate instead of typing."
        case .todo: "Tasks you finish stay on their day, ticked."
        case .profile: "Make categories with your own colours. Turn on sync any time."
        }
    }

    var next: TourStep? { TourStep(rawValue: rawValue + 1) }
    var previous: TourStep? { TourStep(rawValue: rawValue - 1) }
    var isLast: Bool { next == nil }
}
