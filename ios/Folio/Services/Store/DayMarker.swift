import Foundation

/// What a calendar day cell shows (SPEC §6.2), computed from the store and cached per month.
struct DayMarker: Equatable, Sendable {
    var entryCount = 0
    /// The latest entry's first photo, shown as the cell's thumbnail.
    var thumbnailPhotoID: UUID?
    /// Photos on this day beyond the one shown ("+2").
    var extraPhotoCount = 0
    /// Up to 3 category colours for entries without photos, in entry order. nil = uncategorised.
    var dotCategoryIDs: [UUID?] = []
    var openTaskCount = 0
    var doneTaskCount = 0
    /// Every category used on this day, for the filter.
    var categoryIDs: Set<UUID> = []

    var hasEntries: Bool { entryCount > 0 }
    var hasTasks: Bool { openTaskCount + doneTaskCount > 0 }
    var allTasksDone: Bool { hasTasks && openTaskCount == 0 }
    var isEmpty: Bool { !hasEntries && !hasTasks }

    static let maximumDots = 3
}
