import SwiftUI

/// One day in the month grid (SPEC §6.2). Photo days show the latest photo as a tiny
/// rounded tile — the app's signature. Every state also has a non-colour cue (§3.9).
struct DayCell: View {
    let state: DayCellState
    let size: Double
    let categoryColor: (UUID?) -> Color
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(DiaryStore.self) private var store: DiaryStore?
    /// How many times each celebration has played on this day (Batch N); a change plays it.
    @State private var bloomPlays = 0
    @State private var settlePlays = 0
    @State private var sparklePlays = 0
    @State private var bloomStrength = 0.55

    /// The latest celebration, if it's for this day.
    private var celebrationID: UUID? {
        guard let celebration = store?.celebration, celebration.day == state.day else { return nil }
        return celebration.id
    }

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
                if state.hasEvents { eventMark }
                selectionStroke
                CelebrationOverlay(bloomPlays: bloomPlays, bloomStrength: bloomStrength, sparklePlays: sparklePlays, size: size)
            }
            .modifier(PageSettle(trigger: settlePlays))
            .frame(width: size, height: size)
            .contentShape(.rect(cornerRadius: Radius.dayCell))
        }
        .buttonStyle(.pressable)
        .animation(FolioMotion.standard(reduceMotion: reduceMotion), value: state.matchesFilter)
        .onChange(of: celebrationID) { _, id in
            guard id != nil, let kind = store?.celebration?.kind else { return }
            switch kind {
            case .bloom: bloomStrength = 0.55; bloomPlays += 1
            case .settle: bloomStrength = 0.35; bloomPlays += 1; settlePlays += 1
            case .tasksDone: sparklePlays += 1
            }
        }
        .accessibilityLabel(DayCellAccessibility.label(for: state))
        .accessibilityAddTraits(state.isSelected ? .isSelected : [])
    }

    /// Selected day without a photo: an accent square that springs from 0.6 to 1 (SPEC §3.6).
    private var selectionFill: some View {
        RoundedRectangle(cornerRadius: Radius.dayCell)
            .fill(.accentStrong)
            .scaleEffect(state.isSelected || reduceMotion ? 1 : 0.6)
            .opacity(state.isSelected && state.thumbnailPhotoID == nil ? 1 : 0)
            .animation(FolioMotion.confirm(reduceMotion: reduceMotion), value: state.isSelected)
    }

    /// Today without a photo and not selected: accent number plus a thin accent outline. (On a
    /// photo tile today is an accent pill behind the number, `PhotoTileOverlay`.)
    @ViewBuilder private var todayOutline: some View {
        if state.isToday, !state.isSelected, state.thumbnailPhotoID == nil {
            RoundedRectangle(cornerRadius: Radius.dayCell)
                .strokeBorder(.accent.opacity(0.85), lineWidth: 1.5)
                .allowsHitTesting(false)
        }
    }

    /// Selected photo day: an accent frame drawn above the photo and task ring.
    private var selectionStroke: some View {
        RoundedRectangle(cornerRadius: Radius.dayCell)
            .strokeBorder(.accent, lineWidth: 3)
            .scaleEffect(state.isSelected || reduceMotion ? 1 : 0.6)
            .opacity(state.isSelected && state.thumbnailPhotoID != nil ? 1 : 0)
            .animation(FolioMotion.confirm(reduceMotion: reduceMotion), value: state.isSelected)
            .allowsHitTesting(false)
    }

    /// Apple Calendar events (Batch J): a short bar in the bottom-left corner, a zone of its own.
    private var eventMark: some View {
        Capsule()
            .fill(state.thumbnailPhotoID != nil || state.isSelected ? AnyShapeStyle(.white.opacity(0.9)) : AnyShapeStyle(.inkSecondary))
            .frame(width: max(size * 0.18, 6), height: 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(.leading, size * 0.14)
            .padding(.bottom, size * 0.1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
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
                size: 46, categoryColor: { _ in .accent }, onTap: {}
            )
        }
    }
    .padding()
    .background(AuraBackground())
}
