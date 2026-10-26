import Foundation

/// Everything a day cell needs to draw itself, so cells only update when this changes.
struct DayCellState: Equatable {
    let day: DayKey
    let marker: DayMarker?
    let isToday: Bool
    let isSelected: Bool
    let isInMonth: Bool
    /// False when a filter is active and nothing on this day matches it.
    let matchesFilter: Bool
    let showsPhotoTiles: Bool

    var thumbnailPhotoID: UUID? { showsPhotoTiles ? marker?.thumbnailPhotoID : nil }
}
