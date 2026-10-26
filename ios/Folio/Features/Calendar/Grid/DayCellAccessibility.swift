import Foundation

/// The spoken description of a day cell (SPEC §3.9), e.g.
/// "Tuesday 14 October, 2 entries, 1 task done".
enum DayCellAccessibility {
    static func label(for state: DayCellState) -> String {
        var parts = [state.day.utcDate.formatted(Date.FormatStyle(timeZone: .gmt).weekday(.wide).day().month(.wide))]
        if state.isToday { parts.append(String(localized: "today")) }
        if let marker = state.marker {
            if marker.entryCount > 0 {
                parts.append(inflected(AttributedString(localized: "^[\(marker.entryCount) entry](inflect: true)")))
            }
            if marker.thumbnailPhotoID != nil { parts.append(String(localized: "with photos")) }
            if marker.openTaskCount > 0 {
                parts.append(inflected(AttributedString(localized: "^[\(marker.openTaskCount) task](inflect: true) to do")))
            }
            if marker.doneTaskCount > 0 {
                parts.append(inflected(AttributedString(localized: "^[\(marker.doneTaskCount) task](inflect: true) done")))
            }
        }
        return parts.joined(separator: ", ")
    }

    private static func inflected(_ string: AttributedString) -> String {
        String(string.inflected().characters)
    }
}
