import SwiftUI

/// Task marker (SPEC §6.2): a thin ring for open tasks; a green ring plus a tiny check
/// when every task that day is done. The check is the non-colour cue.
struct TaskRing: View {
    let marker: DayMarker?
    let isPhoto: Bool

    var body: some View {
        if let marker, marker.hasTasks {
            RoundedRectangle(cornerRadius: Radius.dayCell)
                .strokeBorder(marker.allTasksDone ? AnyShapeStyle(.done) : AnyShapeStyle(isPhoto ? .white : .inkSecondary),
                              lineWidth: 1.5)
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
}
