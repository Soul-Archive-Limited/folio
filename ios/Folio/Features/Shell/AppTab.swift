import Foundation

/// The four main tabs (SPEC §2).
enum AppTab: Hashable, CaseIterable {
    case calendar, journal, todo, profile

    /// The floating "+" appears on these tabs.
    var showsAddButton: Bool { self != .profile }

    /// Journal and To-do minimise the tab bar on scroll (SPEC §2).
    var minimisesTabBar: Bool { self == .journal || self == .todo }
}
