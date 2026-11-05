import SwiftUI
import WidgetKit

/// Folio's widgets and controls (Batch J). They read only the App Group snapshot the app
/// writes; ticks are queued for the app.
@main
struct FolioWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        MonthWidget()
        QuickAddWidget()
        NextTaskWidget()
        TodayCountWidget()
        NewEntryControl()
        DictateControl()
        AddTaskControl()
    }
}
