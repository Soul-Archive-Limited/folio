import SwiftUI

/// Day number, today's dot and up to three category dots, for days without a photo tile.
struct DayNumberStack: View {
    let state: DayCellState
    let categoryColor: (UUID?) -> Color
    let markerOpacity: Double

    var body: some View {
        VStack(spacing: 3) {
            Text(state.day.day, format: .number)
                .font(.callout.weight(state.isToday || state.isSelected ? .bold : .medium))
                .monospacedDigit()
                .foregroundStyle(numberStyle)
            HStack(spacing: 3) {
                if let marker = state.marker, !marker.dotCategoryIDs.isEmpty {
                    ForEach(Array(marker.dotCategoryIDs.enumerated()), id: \.offset) { _, categoryID in
                        Circle()
                            .fill(state.isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(categoryColor(categoryID)))
                            .frame(width: 5, height: 5)
                    }
                } else if state.isToday && !state.isSelected {
                    Circle().fill(.ember).frame(width: 5, height: 5)
                }
            }
            .frame(height: 5)
            .opacity(markerOpacity)
        }
    }

    private var numberStyle: AnyShapeStyle {
        if state.isSelected { return AnyShapeStyle(.white) }
        if state.isToday { return AnyShapeStyle(.ember) }
        return state.isInMonth ? AnyShapeStyle(.ink) : AnyShapeStyle(.inkTertiary)
    }
}
