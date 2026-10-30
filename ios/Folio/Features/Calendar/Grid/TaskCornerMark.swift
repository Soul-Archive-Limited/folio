import SwiftUI

/// Task marker (SPEC §6.2, redesigned Batch I so marks never overlap): one small symbol in the
/// cell's top-trailing corner, inside the cell — a hollow ring while any task is open, a green
/// check once every task that day is done. The check's shape is the non-colour cue (§3.9).
/// Today, entry dots, photo numbers and "+2" each have their own place, so nothing sits on it.
struct TaskCornerMark: View {
    let marker: DayMarker?
    let isPhoto: Bool
    let isSelected: Bool

    static let inset: Double = 2.5
    static let size: Double = 9

    var body: some View {
        if let marker, marker.hasTasks {
            Group {
                if marker.allTasksDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 6, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: Self.size + 1, height: Self.size + 1)
                        .background(.done, in: .circle)
                        .overlay { if isPhoto { Circle().strokeBorder(.white.opacity(0.9), lineWidth: 0.75) } }
                } else {
                    Circle()
                        .strokeBorder(ringStyle, lineWidth: 1.5)
                        .frame(width: Self.size - 1, height: Self.size - 1)
                        .shadow(color: isPhoto ? .black.opacity(0.5) : .clear, radius: 1)
                }
            }
            .padding(Self.inset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .accessibilityHidden(true)
        }
    }

    private var ringStyle: AnyShapeStyle {
        if isPhoto || isSelected { return AnyShapeStyle(.white) }
        return AnyShapeStyle(.inkSecondary)
    }
}
