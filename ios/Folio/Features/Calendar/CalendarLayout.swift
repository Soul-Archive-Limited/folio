import Foundation

/// Calendar geometry derived from the available width (SPEC §6.2: 6×7 grid, gap 6).
struct CalendarLayout: Equatable {
    static let gap: Double = 6
    static let panelPadding: Double = 8

    /// Screen width.
    let width: Double

    /// Width of the glass panel (and of each month page inside it).
    var panelWidth: Double { width - Spacing.sideMargin * 2 }

    var cellSize: Double {
        max((panelWidth - Self.panelPadding * 2 - Self.gap * 6) / 7, 24)
    }

    var rowHeight: Double { cellSize + Self.gap }
    var fullGridHeight: Double { cellSize * 6 + Self.gap * 5 + Self.panelPadding * 2 }
    var weekHeight: Double { cellSize + Self.panelPadding * 2 }
    var collapseDistance: Double { fullGridHeight - weekHeight }

    func gridHeight(progress: Double) -> Double {
        fullGridHeight - collapseDistance * min(max(progress, 0), 1)
    }
}
