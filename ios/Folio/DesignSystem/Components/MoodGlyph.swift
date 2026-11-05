import SwiftUI

/// Folio's mood mark (Batch J): a ring that fills from the bottom, cool to warm. Not a face.
/// `nil` draws the empty ring (no mood set).
struct MoodGlyph: View {
    let mood: Mood?
    var size: Double = 22

    var body: some View {
        let ring = max(size / 11, 1.5)
        ZStack {
            Circle().strokeBorder((mood?.color ?? .inkSecondary).opacity(mood == nil ? 0.7 : 1), lineWidth: ring)
            if let mood {
                Circle()
                    .inset(by: ring + 1)
                    .fill(mood.color)
                    .mask(alignment: .bottom) {
                        Rectangle().frame(height: size * mood.fill)
                    }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// The composer's mood button and its picker (Batch J).
struct ComposerMoodButton: View {
    @Binding var mood: Mood?
    @State private var showsPicker = false

    var body: some View {
        Button { showsPicker = true } label: {
            MoodGlyph(mood: mood, size: 21)
                .frame(width: Spacing.minHitTarget, height: Spacing.minHitTarget)
                .contentShape(.rect)
        }
        .accessibilityLabel(mood.map { String(localized: "Mood, \($0.title)") } ?? String(localized: "Mood"))
        .accessibilityIdentifier("composer.mood")
        .popover(isPresented: $showsPicker) {
            MoodPicker(mood: $mood) { showsPicker = false }
                .presentationCompactAdaptation(.popover)
        }
    }
}

struct MoodPicker: View {
    @Binding var mood: Mood?
    let onPick: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("How did it feel?").folioFont(.caption).foregroundStyle(.inkSecondary)
            HStack(spacing: Spacing.s) {
                ForEach(Mood.allCases) { option in
                    Button {
                        mood = mood == option ? nil : option
                        onPick()
                    } label: {
                        VStack(spacing: Spacing.xxs) {
                            MoodGlyph(mood: option, size: 30)
                                .padding(4)
                                .background(Circle().fill(mood == option ? option.color.opacity(0.18) : .clear))
                            Text(option.title).font(.caption2.weight(mood == option ? .bold : .regular)).foregroundStyle(.ink)
                        }
                        .frame(minWidth: 48, minHeight: Spacing.minHitTarget)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.title)
                    .accessibilityAddTraits(mood == option ? .isSelected : [])
                }
            }
            if mood != nil {
                Button("Clear", role: .destructive) { mood = nil; onPick() }.font(.footnote)
            }
        }
        .padding(Spacing.m)
        .folioHaptic(.selection, trigger: mood)
    }
}
