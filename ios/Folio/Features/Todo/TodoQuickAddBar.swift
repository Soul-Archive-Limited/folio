import SwiftUI

/// The full-width glass quick-add bar above the tab bar (SPEC §6.7). "Call Mum tomorrow" is
/// dated tomorrow; Return adds and keeps the keyboard up for the next one. The expand button
/// opens the full task composer with whatever has been typed so far.
struct TodoQuickAddBar: View {
    let onExpand: (_ title: String, _ day: DayKey?) -> Void

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
            Button("Open task composer", systemImage: "arrow.up.left.and.arrow.down.right", action: expand)
                .labelStyle(.iconOnly)
                .font(.body.weight(.semibold))
                .foregroundStyle(.inkSecondary)
                .frame(width: Spacing.minHitTarget, height: Spacing.minHitTarget)
                .contentShape(.rect)
                .accessibilityInputLabels(["Expand", "Open task composer", "Full composer"])
        }
        .padding(.leading, Spacing.m)
        .padding(.trailing, Spacing.xxs)
        .frame(minHeight: 48)
        .folioGlass(in: .capsule, interactive: true)
        .padding(.horizontal, Spacing.sideMargin)
        .padding(.bottom, Spacing.s)
        .folioHaptic(.success, trigger: addedCount)
    }

    private func add() {
        let parsed = QuickAddParser.parse(text, today: store.today)
        guard !parsed.title.isEmpty, (try? store.createTask(title: parsed.title, day: parsed.day)) != nil else { return }
        text = ""
        addedCount += 1
        isFocused = true
    }

    private func expand() {
        let parsed = QuickAddParser.parse(text, today: store.today)
        isFocused = false
        text = ""
        onExpand(parsed.title, parsed.day)
    }
}
