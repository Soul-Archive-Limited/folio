import SwiftUI

/// Lets Profile open another tab already filtered (SPEC §6.9 "tap → filtered tab"), and
/// return to the calendar for the tour replay. A class in the environment, like
/// `NewItemRequester`.
@Observable
final class TabRouter {
    enum Destination: Equatable {
        case entries, photos, daysWrittenOn, tasksDone
    }

    var pending: Destination?

    func open(_ destination: Destination) {
        pending = destination
    }
}

extension EnvironmentValues {
    @Entry var tabRouter: TabRouter?
}
