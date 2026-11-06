import SwiftUI

/// Hardware-keyboard shortcuts (Batch L, iPad and keyboards on iPhone): they appear in the
/// iPadOS menu bar and the ⌘ overlay, and act on the focused window only (`focusedSceneValue`),
/// so with two Folio windows open ⌘N opens one composer, in the window you're using.
enum FolioCommand: Hashable {
    case newEntry, newTask, search, today, previousMonth, nextMonth
    case tab(AppTab)
}

/// What the focused window does with a command.
struct FolioCommandHandler {
    let perform: (FolioCommand) -> Void
}

extension FocusedValues {
    @Entry var folioCommands: FolioCommandHandler?
}

struct FolioCommands: Commands {
    @FocusedValue(\.folioCommands) private var handler

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Entry") { handler?.perform(.newEntry) }
                .keyboardShortcut("n")
            Button("New Task") { handler?.perform(.newTask) }
                .keyboardShortcut("n", modifiers: [.command, .shift])
        }
        CommandMenu("Go") {
            Button("Calendar") { handler?.perform(.tab(.calendar)) }.keyboardShortcut("1")
            Button("Journal") { handler?.perform(.tab(.journal)) }.keyboardShortcut("2")
            Button("To-do") { handler?.perform(.tab(.todo)) }.keyboardShortcut("3")
            Button("Profile") { handler?.perform(.tab(.profile)) }.keyboardShortcut("4")
            Divider()
            Button("Today") { handler?.perform(.today) }.keyboardShortcut("t")
            Button("Previous Month") { handler?.perform(.previousMonth) }.keyboardShortcut("[")
            Button("Next Month") { handler?.perform(.nextMonth) }.keyboardShortcut("]")
            Divider()
            Button("Search") { handler?.perform(.search) }.keyboardShortcut("f")
        }
    }
}
