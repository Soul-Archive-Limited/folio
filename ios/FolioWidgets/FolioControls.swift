import AppIntents
import SwiftUI
import WidgetKit

/// Control Center and Action Button (Batch J): New entry, Dictate, Add task.
struct NewEntryControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.devilsense.folio.control.newEntry") {
            ControlWidgetButton(action: NewEntryIntent()) {
                Label("New Entry", image: "folio.page.new")
            }
        }
        .displayName("New Entry")
        .description("A new page for today in Folio.")
    }
}

struct DictateControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.devilsense.folio.control.dictate") {
            ControlWidgetButton(action: DictateEntryIntent()) {
                Label("Dictate", image: "folio.dictate")
            }
        }
        .displayName("Dictate Entry")
        .description("A new page with dictation already listening.")
    }
}

struct AddTaskControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.devilsense.folio.control.addTask") {
            ControlWidgetButton(action: OpenNewTaskIntent()) {
                Label("Add Task", image: "folio.task.add")
            }
        }
        .displayName("Add Task")
        .description("Folio's quick add for a new task.")
    }
}
