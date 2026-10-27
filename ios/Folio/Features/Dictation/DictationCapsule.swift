import SwiftUI

/// The glass dictation capsule (SPEC §6.11): live waveform, the words being heard (dim
/// while volatile, ink once final), Pause and Done. While the speech model downloads it
/// shows a progress row instead.
struct DictationCapsule: View {
    let session: DictationSession
    let onDone: () -> Void
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Spacing.s) {
            switch session.state {
            case .downloading(let fraction):
                Image(systemName: "arrow.down.circle").foregroundStyle(.ember).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Getting dictation ready on your iPhone…").folioFont(.callout).foregroundStyle(.ink)
                    ProgressView(value: fraction).tint(.emberStrong)
                        .accessibilityLabel("Speech model download")
                        .accessibilityValue(Text(fraction, format: .percent.precision(.fractionLength(0))))
                }
            case .unavailable(let message):
                Image(systemName: "mic.slash").foregroundStyle(.inkSecondary).accessibilityHidden(true)
                Text(message).folioFont(.callout).foregroundStyle(.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button("OK", action: onDismiss).buttonStyle(.glass)
            default:
                DictationWaveform(levels: session.levels, isActive: session.state == .listening, reduceMotion: reduceMotion)
                    .frame(width: 64, height: 32)
                    .accessibilityHidden(true)
                transcript
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(session.state == .paused ? "Resume" : "Pause",
                       systemImage: session.state == .paused ? "mic.fill" : "pause.fill",
                       action: session.togglePause)
                    .labelStyle(.iconOnly)
                    .font(.headline)
                    .frame(width: Spacing.minHitTarget, height: Spacing.minHitTarget)
                    .disabled(session.state == .preparing)
                Button("Done", action: onDone)
                    .buttonStyle(.glassProminent)
                    .tint(.emberStrong)
            }
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .frame(minHeight: 60)
        .folioGlass(in: .rect(cornerRadius: 28))
        .padding(.horizontal, Spacing.sideMargin)
        .padding(.bottom, Spacing.xs)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Dictation")
    }

    private var transcript: some View {
        let status: LocalizedStringKey = switch session.state {
        case .paused: "Paused"
        case .preparing: "Starting…"
        default: "Listening…"
        }
        return VStack(alignment: .leading, spacing: 2) {
            Text(status).folioFont(.caption).foregroundStyle(.inkTertiary)
            let committed = Text(session.lastCommitted.isEmpty ? "" : session.lastCommitted + " ").foregroundStyle(.ink)
            let volatile = Text(session.volatileText).foregroundStyle(.inkTertiary)
            Text("\(committed)\(volatile)")
                .folioFont(.callout)
                .lineLimit(2)
                .truncationMode(.head)
                .contentTransition(.opacity)
        }
    }
}

/// Bars from recent mic levels; still bars (no motion) under Reduce Motion.
struct DictationWaveform: View {
    let levels: [Float]
    let isActive: Bool
    let reduceMotion: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 1.5) {
            ForEach(Array(levels.suffix(16).enumerated()), id: \.offset) { _, level in
                Capsule()
                    .fill(isActive ? Color.ember : Color.inkTertiary)
                    .frame(width: 2.5, height: max(3, 32 * Double(reduceMotion ? min(level, 0.3) : level)))
            }
        }
        .animation(reduceMotion ? nil : .linear(duration: 0.08), value: levels)
    }
}
