import SwiftUI

/// Task marker (SPEC §6.2): a 1 pt ring for open tasks; a 1 pt green ring plus a tiny check
/// when every task that day is done. The check is the non-colour cue. Kept deliberately
/// quiet so task-heavy weeks don't overpower photos and dots (owner review, Batch A).
struct TaskRing: View {
    let marker: DayMarker?
    let isPhoto: Bool

    var body: some View {
        if let marker, marker.hasTasks {
            RoundedRectangle(cornerRadius: Radius.dayCell)
                .strokeBorder(ringStyle(marker), lineWidth: 1)
                .overlay(alignment: .topTrailing) {
                    if marker.allTasksDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: 7, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(width: 11, height: 11)
                            .background(.done, in: .circle)
                            .offset(x: 3, y: -3)
                    }
                }
                .accessibilityHidden(true)
        }
    }

    private func ringStyle(_ marker: DayMarker) -> AnyShapeStyle {
        if marker.allTasksDone { return AnyShapeStyle(.done) }
        return isPhoto ? AnyShapeStyle(.white.opacity(0.75)) : AnyShapeStyle(.inkSecondary)
    }
}
