import SwiftUI

/// Minimal read-only entry view until the full entry detail (Phase 4).
struct EntryDetailPlaceholder: View {
    let entryID: UUID
    @Environment(DiaryStore.self) private var store

    var body: some View {
        ScrollView {
            if let entry = store.allEntries().first(where: { $0.id == entryID }) {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    if let photo = entry.orderedPhotos.first {
                        PhotoTile(photoID: photo.id, cornerRadius: Radius.photo)
                            .aspectRatio(4 / 3, contentMode: .fit)
                    }
                    if let day = entry.day {
                        Text(day.utcDate, format: Date.FormatStyle(timeZone: .gmt).weekday(.wide).day().month(.wide).year())
                            .folioFont(.caption).foregroundStyle(.inkTertiary)
                    }
                    Text(entry.title).folioFont(.title2)
                    Text(MarkdownCodec.document(from: entry.bodyMarkdown).plainText)
                        .font(WritingFont.newYork.font())
                        .lineSpacing(6)
                }
                .padding(Spacing.sideMargin)
            }
        }
        .background { AuraBackground() }
        .navigationBarTitleDisplayMode(.inline)
    }
}
