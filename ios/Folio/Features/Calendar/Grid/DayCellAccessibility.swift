import Foundation

/// The spoken description of a day cell (SPEC §3.9), e.g.
/// "Tuesday 14 October, 2 entries, 1 task done".
enum DayCellAccessibility {
    /// What the label depends on. Labels are cached: each month page builds 42 of them in its
    /// body, and inflected strings and date formatting showed up as paging hitches (Phase 13).
    private struct Key: Hashable {
        let day: DayKey, isToday: Bool, entries: Int, hasPhoto: Bool, open: Int, done: Int
    }

    private static var cache: [Key: String] = [:]
    private static let dateStyle = Date.FormatStyle(timeZone: .gmt).weekday(.wide).day().month(.wide)

    static func label(for state: DayCellState) -> String {
        let marker = state.marker
        let key = Key(day: state.day, isToday: state.isToday, entries: marker?.entryCount ?? 0,
                      hasPhoto: marker?.thumbnailPhotoID != nil, open: marker?.openTaskCount ?? 0, done: marker?.doneTaskCount ?? 0)
        if let cached = cache[key] { return cached }
        if cache.count > 4_000 { cache.removeAll(keepingCapacity: true) }
        let label = makeLabel(for: state)
        cache[key] = label
        return label
    }

    private static func makeLabel(for state: DayCellState) -> String {
        var parts = [state.day.utcDate.formatted(dateStyle)]
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
