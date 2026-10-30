import SwiftUI

/// Day number and up to three category dots under it, for days without a photo tile.
/// Today is the ember number (and the cell's outline, `DayCell`); no dot, so dots only ever mean entries.
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
                }
            }
            .frame(height: 5)
            .opacity(markerOpacity)
        }
    }

    private var numberStyle: AnyShapeStyle {
        if state.isSelected { return AnyShapeStyle(.white) }
        if state.isToday { return AnyShapeStyle(.emberText) }
        return state.isInMonth ? AnyShapeStyle(.ink) : AnyShapeStyle(.inkTertiary)
    }
}
