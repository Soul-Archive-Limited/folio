#if DEBUG
import SwiftUI

/// DEBUG-only scripted flows for the Phase 13 hitch audit (`-FolioPerfScript YES`, with
/// `-FolioHitchLog YES`). Driving the app from inside keeps XCUITest's accessibility snapshots
/// — which run on the app's main thread — out of the measurement.
@MainActor
enum PerfDriver {
    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: "FolioPerfScript") }

    static func run(calendar: CalendarModel, requester: NewItemRequester, select: (AppTab) -> Void) async {
        let monitor = HitchMonitor.shared
        try? await Task.sleep(for: .seconds(3))
        monitor.mark("paging")
        for step in [1, 1, 1, 1, 1, 1, -1, -1, -1, -1, -1, -1] {
            withAnimation(FolioMotion.standard()) {
                calendar.visibleMonthID = calendar.visibleMonth.adding(months: step).id
            }
            try? await Task.sleep(for: .milliseconds(700))
        }
        monitor.mark("composer")
        for _ in 0..<3 {
            requester.send(.entry(calendar.selectedDay))
            try? await Task.sleep(for: .milliseconds(1200))
            requester.pending = nil
            try? await Task.sleep(for: .milliseconds(1000))
        }
        monitor.mark("journal")
        select(.journal)
        try? await Task.sleep(for: .seconds(2))
        // Scrolling is done by hand (or the Simulator tool) after this mark.
        monitor.mark("scroll")
    }
}
#endif
