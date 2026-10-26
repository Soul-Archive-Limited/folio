import SwiftUI

/// The glass quick-add bar above the tab bar (SPEC §6.7). "Call Mum tomorrow" is dated
/// tomorrow; Return adds and keeps the keyboard up for the next one.
struct TodoQuickAddBar: View {
    @Environment(DiaryStore.self) private var store
    @State private var text = ""
    @State private var addedCount = 0
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(.ember)
                .accessibilityHidden(true)
            TextField("Add a task…", text: $text)
                .focused($isFocused)
                .submitLabel(.done)
                .onSubmit(add)
        }
        .padding(.horizontal, Spacing.m)
        .frame(minHeight: 48)
        .folioGlass(in: .capsule, interactive: true)
        .padding(.leading, Spacing.sideMargin)
        // Leave room for the floating "+" so the two never overlap.
        .padding(.trailing, Spacing.sideMargin + FloatingButtonMetrics.diameter + Spacing.s)
        .padding(.bottom, Spacing.m + 4)
        .folioHaptic(.success, trigger: addedCount)
    }

    private func add() {
        let parsed = QuickAddParser.parse(text, today: store.today)
        guard !parsed.title.isEmpty, (try? store.createTask(title: parsed.title, day: parsed.day)) != nil else { return }
        text = ""
        addedCount += 1
        isFocused = true
    }
}
