import SwiftUI
import TipKit

/// Runs the guided tour (SPEC §6.15) as one ordered `TipGroup` shared by every screen that
/// anchors a tip, so only the current step is ever shown.
@Observable
final class TourModel {
    @ObservationIgnored let group = TipGroup(.ordered) {
        MonthGridTip()
        TapDayTip()
        AddEntryTip()
        ComposerToolsTip()
        TodoTabTip()
        ProfileTabTip()
    }

    private static let allTips: [any Tip] = [
        MonthGridTip(), TapDayTip(), AddEntryTip(), ComposerToolsTip(), TodoTabTip(), ProfileTabTip(),
    ]

    /// The tip to show now, if it's of the type the caller anchors.
    func current<T: Tip>(_ type: T.Type) -> T? {
        group.currentTip as? T
    }

    func start() {
        MonthGridTip.tourActive = true
    }

    /// Profile → Help → "Show the tour again".
    func replay() async {
        for tip in Self.allTips { await tip.resetEligibility() }
        MonthGridTip.tourActive = true
    }

    func skip() {
        for tip in Self.allTips { tip.invalidate(reason: .tipClosed) }
        MonthGridTip.tourActive = false
    }

    /// Routes a tip's buttons: Next and Got it finish that step, Skip ends the tour.
    func handle(_ action: Tips.Action, for tip: some Tip) {
        switch action.id {
        case TourAction.skip: skip()
        default: tip.invalidate(reason: .actionPerformed)
        }
    }

    // MARK: Steps that finish when the user does the thing

    func didSelectDay() { TapDayTip().invalidate(reason: .actionPerformed) }
    func didOpenComposer() { AddEntryTip().invalidate(reason: .actionPerformed) }
    func didCloseComposer() { ComposerToolsTip().invalidate(reason: .actionPerformed) }

    func didSelect(_ tab: AppTab) {
        switch tab {
        case .todo: TodoTabTip().invalidate(reason: .actionPerformed)
        case .profile:
            ProfileTabTip().invalidate(reason: .actionPerformed)
            MonthGridTip.tourActive = false
        default: break
        }
    }

    // MARK: Setup

    /// Call once from `App.init`, before any tip can show.
    static func configure() {
        #if DEBUG
        let step = UserDefaults.standard.integer(forKey: "FolioTourStep")
        if step > 0 { try? Tips.resetDatastore() }
        #endif
        do {
            try Tips.configure([.displayFrequency(.immediate), .datastoreLocation(.applicationDefault)])
        } catch {
            FolioPersistence.logger.error("TipKit configuration failed: \(String(describing: type(of: error)), privacy: .public)")
        }
        #if DEBUG
        if step > 0 {
            MonthGridTip.tourActive = true
            for tip in allTips.prefix(step - 1) { tip.invalidate(reason: .actionPerformed) }
        }
        #endif
    }
}

extension View {
    /// Anchors a tour tip here when it's the current step, wiring its buttons to the tour.
    func tourTip<T: Tip>(_ type: T.Type, _ tour: TourModel?, arrowEdge: Edge = .top) -> some View {
        let tip = tour?.current(type)
        return popoverTip(tip, arrowEdge: arrowEdge) { action in
            if let tip { tour?.handle(action, for: tip) }
        }
        .tint(.ember)
    }
}
