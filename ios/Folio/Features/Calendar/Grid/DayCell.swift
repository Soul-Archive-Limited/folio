import SwiftUI

/// One day in the month grid (SPEC §6.2). Photo days show the latest photo as a tiny
/// rounded tile — the app's signature. Every state also has a non-colour cue (§3.9).
struct DayCell: View {
    let state: DayCellState
    let size: Double
    let categoryColor: (UUID?) -> Color
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onTap) {
            ZStack {
                selectionFill
                if let photoID = state.thumbnailPhotoID {
                    PhotoTile(photoID: photoID, cornerRadius: Radius.dayCell)
                        .opacity(markerOpacity)
                    PhotoTileOverlay(state: state, size: size)
                } else {
                    DayNumberStack(state: state, categoryColor: categoryColor, markerOpacity: markerOpacity)
                }
                todayOutline
                TaskCornerMark(marker: state.marker, isPhoto: state.thumbnailPhotoID != nil, isSelected: state.isSelected)
                    .opacity(markerOpacity)
                selectionStroke
            }
            .frame(width: size, height: size)
            .contentShape(.rect(cornerRadius: Radius.dayCell))
        }
        .buttonStyle(.pressable)
        .animation(FolioMotion.standard(reduceMotion: reduceMotion), value: state.matchesFilter)
        .accessibilityLabel(DayCellAccessibility.label(for: state))
        .accessibilityAddTraits(state.isSelected ? .isSelected : [])
    }

    /// Selected day without a photo: an ember square that springs from 0.6 to 1 (SPEC §3.6).
    private var selectionFill: some View {
        RoundedRectangle(cornerRadius: Radius.dayCell)
            .fill(.emberStrong)
            .scaleEffect(state.isSelected || reduceMotion ? 1 : 0.6)
            .opacity(state.isSelected && state.thumbnailPhotoID == nil ? 1 : 0)
            .animation(FolioMotion.confirm(reduceMotion: reduceMotion), value: state.isSelected)
    }

    /// Today without a photo and not selected: ember number plus a thin ember outline. (On a
    /// photo tile today is an ember pill behind the number, `PhotoTileOverlay`.)
    @ViewBuilder private var todayOutline: some View {
        if state.isToday, !state.isSelected, state.thumbnailPhotoID == nil {
            RoundedRectangle(cornerRadius: Radius.dayCell)
                .strokeBorder(.ember.opacity(0.85), lineWidth: 1.5)
                .allowsHitTesting(false)
        }
    }

    /// Selected photo day: an ember frame drawn above the photo and task ring.
    private var selectionStroke: some View {
        RoundedRectangle(cornerRadius: Radius.dayCell)
            .strokeBorder(.ember, lineWidth: 3)
            .scaleEffect(state.isSelected || reduceMotion ? 1 : 0.6)
            .opacity(state.isSelected && state.thumbnailPhotoID != nil ? 1 : 0)
            .animation(FolioMotion.confirm(reduceMotion: reduceMotion), value: state.isSelected)
            .allowsHitTesting(false)
    }

    /// Non-matching days fade their markers to 15 % while a filter is on (SPEC §6.2).
    private var markerOpacity: Double { state.matchesFilter ? 1 : 0.15 }
}

#Preview {
    let today = DayKey(date: .now, calendar: .current)
    HStack {
        ForEach(0..<4, id: \.self) { index in
            DayCell(
                state: DayCellState(day: today.adding(days: index), marker: DayMarker(entryCount: index, dotCategoryIDs: [nil, nil],
                                    openTaskCount: index == 2 ? 1 : 0, doneTaskCount: index == 3 ? 2 : 0),
                                    isToday: index == 0, isSelected: index == 1, isInMonth: true, matchesFilter: true, showsPhotoTiles: true),
                size: 46, categoryColor: { _ in .ember }, onTap: {}
            )
        }
    }
    .padding()
    .background(AuraBackground())
}
