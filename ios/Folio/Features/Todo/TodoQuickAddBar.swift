import SwiftUI

/// The full-width glass quick-add bar above the tab bar (SPEC §6.7). It reads natural dates
/// and times ("Call Mum tomorrow 6pm", "Pay rent on 5 Nov", `QuickAddParser`) and shows what
/// it understood in a chip above the bar before saving (Batch I); Return adds and keeps the
/// keyboard up for the next one. The expand button opens the full task composer with it.
struct TodoQuickAddBar: View {
    /// Space before the bar: the side margin, or room for the minimised tab bar beside it.
    var leadingInset: Double = Spacing.sideMargin
    var onFocusChange: (Bool) -> Void = { _ in }
    let onExpand: (QuickAddParser.Result) -> Void

    @Environment(DiaryStore.self) private var store
    @State private var text = ""
    @State private var addedCount = 0
    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let parsed = parse()
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if let summary = parsed.summary(today: store.today) {
                Label(summary, systemImage: parsed.minutesFromMidnight == nil ? "calendar" : "clock")
                    .folioFont(.caption)
                    .foregroundStyle(.emberText)
                    .padding(.horizontal, Spacing.s)
                    .frame(minHeight: 28)
                    .folioGlass(in: .capsule)
                    .padding(.leading, leadingInset)
                    .transition(FolioMotion.transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottomLeading)), reduceMotion: reduceMotion))
                    .accessibilityLabel(Text("Will be added for \(summary)"))
                    .id(summary)
            }
            bar
        }
        .animation(FolioMotion.standard(reduceMotion: reduceMotion), value: parsed.summary(today: store.today))
    }

    private var bar: some View {
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
        .padding(.leading, leadingInset)
        .padding(.trailing, Spacing.sideMargin)
        .padding(.bottom, Spacing.s)
        .onChange(of: isFocused) { _, focused in onFocusChange(focused) }
        .folioHaptic(.success, trigger: addedCount)
    }

    private func parse() -> QuickAddParser.Result {
        QuickAddParser.parse(text, now: store.now(), calendar: store.calendar)
    }

    private func add() {
        let parsed = parse()
        guard !parsed.title.isEmpty,
              (try? store.createTask(title: parsed.title, day: parsed.day, minutesFromMidnight: parsed.minutesFromMidnight)) != nil else { return }
        text = ""
        addedCount += 1
        isFocused = true
    }

    private func expand() {
        let parsed = parse()
        isFocused = false
        text = ""
        onExpand(parsed)
    }
}
