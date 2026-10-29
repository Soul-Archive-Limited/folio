import SwiftUI

/// An entry in the day panel (SPEC §6.2): 64 pt photo, title, two-line preview,
/// category and time.
struct EntryCard: View {
    let entry: Entry
    let category: Category?
    let calendar: Calendar

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            if let photo = entry.orderedPhotos.first {
                FullPhotoImage(photoID: photo.id, rendition: .display, maxPixel: 240, cornerRadius: 14)
                    .frame(width: 64, height: 64)
            }
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(entry.title.isEmpty ? String(localized: "Untitled") : entry.title)
                    .folioFont(.headline)
                    .foregroundStyle(.ink)
                    .lineLimit(1)
                if !preview.isEmpty {
                    Text(preview)
                        .folioFont(.callout)
                        .foregroundStyle(.inkSecondary)
                        .lineLimit(2)
                }
                HStack(spacing: Spacing.s) {
                    if let category { CategoryTag(category: category) }
                    if let time { Text(time, format: .dateTime.hour().minute()).folioFont(.caption).foregroundStyle(.inkSecondary) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Spacing.s)
        // Behind the content and not interactive: either would take the long press from the
        // card's context menu.
        .folioGlass(in: .rect(cornerRadius: Radius.card), behindContent: true)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the entry")
        .accessibilityIdentifier("entry-card")
    }

    private var preview: String {
        MarkdownCodec.document(from: entry.bodyMarkdown).plainText
            .replacing("\n", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    private var time: Date? {
        guard let minutes = entry.minutesFromMidnight, let day = entry.day else { return nil }
        return calendar.date(byAdding: .minute, value: minutes, to: day.startDate(in: calendar))
    }
}
