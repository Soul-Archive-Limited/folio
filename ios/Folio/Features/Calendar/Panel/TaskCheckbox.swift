import SwiftUI

/// A 26 pt circular checkbox in the category colour. Ticking fills it and draws the check
/// (trim 0 → 1 over 0.25 s) with a success haptic (SPEC §3.6, §3.7).
struct TaskCheckbox: View {
    let isOn: Bool
    let tint: Color
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().strokeBorder(tint, lineWidth: 2)
                Circle().fill(tint).scaleEffect(isOn ? 1 : 0.4).opacity(isOn ? 1 : 0)
                CheckmarkShape()
                    .trim(from: 0, to: isOn ? 1 : 0)
                    .stroke(.white, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                    .padding(7)
            }
            .frame(width: 26, height: 26)
            .frame(width: Spacing.minHitTarget, height: Spacing.minHitTarget)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .animation(reduceMotion ? FolioMotion.reduced : .easeOut(duration: 0.25), value: isOn)
        .accessibilityLabel(isOn ? "Done" : "Not done")
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .sensoryFeedback(isOn ? .success : .impact(weight: .light), trigger: isOn)
    }
}

/// A hand-tuned checkmark path that can be trimmed for the draw-on animation.
nonisolated struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY + rect.height * 0.05))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.maxY - rect.height * 0.1))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.1))
        return path
    }
}
