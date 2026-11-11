import SwiftUI

/// A Timeline card: 16:9 cover photo with the title over a gradient, or a text card.
struct JournalEntryCard: View {
    let entry: Entry

    @Environment(DiaryStore.self) private var store

    var body: some View {
        if let cover = entry.orderedPhotos.first {
            // A clear 16:9 frame carries the size; the photo fills it (an image would impose its own ratio).
            Color.clear
                .aspectRatio(16 / 9, contentMode: .fit)
                .overlay { FullPhotoImage(photoID: cover.id, rendition: .display, maxPixel: 1080, cornerRadius: Radius.card) }
                .clipShape(.rect(cornerRadius: Radius.card))
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 2) {
                        dateLine.foregroundStyle(.white)
                        Text(displayTitle).folioFont(.title2).foregroundStyle(.white).lineLimit(2)
                        if let place = entry.place {
                            PlaceLine(place: place).foregroundStyle(.white.opacity(0.9))
                        }
                    }
                    .padding(Spacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(LinearGradient(colors: [.black.opacity(0.7), .black.opacity(0.35), .clear], startPoint: .bottom, endPoint: .top))
                }
                .clipShape(.rect(cornerRadius: Radius.card))
                .contentShape(.rect(cornerRadius: Radius.card))
                .overlay { RoundedRectangle(cornerRadius: Radius.card).strokeBorder(.hairline, lineWidth: 1) }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("entry-card")
        } else {
            HStack(alignment: .top, spacing: Spacing.s) {
                textColumn
                if let coordinate = entry.place?.coordinate {
                    // A text card with a place shows a small map of it (Batch N).
                    PlaceSnapshot(coordinate: coordinate, span: 0.02)
                        .frame(width: 72, height: 72)
                        .clipShape(.rect(cornerRadius: 14))
                }
            }
            .padding(Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Behind the content and not interactive: either would take the long press
            // from the card's context menu.
            .folioGlass(in: .rect(cornerRadius: Radius.card), behindContent: true)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("entry-card")
        }
    }

    private var textColumn: some View {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                dateLine.foregroundStyle(.inkSecondary)
                Text(displayTitle).folioFont(.headline).foregroundStyle(.ink)
                if !preview.isEmpty {
                    Text(preview).folioFont(.callout).foregroundStyle(.inkSecondary).lineLimit(3)
                }
                if let mood = entry.mood.flatMap(Mood.init(rawValue:)) {
                    MoodGlyph(mood: mood, size: 12).accessibilityLabel(mood.title)
                }
                if let category = store.category(id: entry.categoryID) { CategoryTag(category: category) }
                if let place = entry.place { PlaceLine(place: place) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The title, else the first line of the words (Batch O: no "Untitled" over words).
    private var displayTitle: String { entry.displayTitle }

    private var preview: String {
        let lines = MarkdownCodec.document(from: entry.bodyMarkdown).plainText.split(whereSeparator: \.isNewline)
        // With no title the first line is already the heading.
        return lines.dropFirst(entry.title.isEmpty ? 1 : 0).joined(separator: " ")
    }

    @ViewBuilder private var dateLine: some View {
        if let day = entry.day {
            Text(day.utcDate.formatted(Date.FormatStyle(timeZone: .gmt).weekday(.abbreviated).day().month(.abbreviated)))
                .folioFont(.caption)
        }
    }
}
