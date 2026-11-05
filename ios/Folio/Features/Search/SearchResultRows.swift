import SwiftUI

/// A page in the search results: photo, date, highlighted title and snippet, category (Batch J).
struct SearchEntryRow: View {
    let document: SearchIndex.Document
    let terms: [String]
    let category: Category?

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            if let photoID = document.firstPhotoID {
                FullPhotoImage(photoID: photoID, rendition: .display, maxPixel: 240, cornerRadius: 12)
                    .frame(width: 52, height: 52)
            }
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(SearchDateLine.text(document.dayKey))
                    .folioFont(.caption)
                    .foregroundStyle(.inkSecondary)
                Text(SearchHighlight.attributed(document.title.isEmpty ? String(localized: "Untitled") : document.title, terms: terms))
                    .folioFont(.headline)
                    .foregroundStyle(.ink)
                    .lineLimit(1)
                let snippet = SearchHighlight.snippet(document.text, terms: terms)
                if !snippet.isEmpty {
                    Text(SearchHighlight.attributed(snippet, terms: terms))
                        .folioFont(.callout)
                        .foregroundStyle(.inkSecondary)
                        .lineLimit(2)
                }
                if let category { CategoryTag(category: category) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Spacing.s)
        .folioGlass(in: .rect(cornerRadius: Radius.card), behindContent: true)
        .contentShape(.rect(cornerRadius: Radius.card))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the page")
        .accessibilityIdentifier("search-entry")
    }
}

/// A task in the search results, with any matching subtasks under it (Batch J).
struct SearchTaskRow: View {
    let document: SearchIndex.Document
    let terms: [String]
    let category: Category?

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            Image(systemName: document.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(document.isCompleted ? Color.done : (category?.color.color ?? .inkSecondary))
                .accessibilityLabel(document.isCompleted ? "Done" : "Open")
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(SearchHighlight.attributed(document.title, terms: terms))
                    .folioFont(.headline)
                    .foregroundStyle(.ink)
                    .strikethrough(document.isCompleted, color: .inkSecondary)
                ForEach(matchingSubtasks, id: \.self) { title in
                    Label { Text(SearchHighlight.attributed(title, terms: terms)) } icon: { Image(systemName: "arrow.turn.down.right") }
                        .folioFont(.callout)
                        .foregroundStyle(.inkSecondary)
                }
                if !document.text.isEmpty {
                    Text(SearchHighlight.attributed(SearchHighlight.snippet(document.text, terms: terms), terms: terms))
                        .folioFont(.callout)
                        .foregroundStyle(.inkSecondary)
                        .lineLimit(1)
                }
                HStack(spacing: Spacing.s) {
                    if document.dayKey != nil {
                        Text(SearchDateLine.text(document.dayKey)).folioFont(.caption).foregroundStyle(.inkSecondary)
                    }
                    if let category { CategoryTag(category: category) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Spacing.s)
        .folioGlass(in: .rect(cornerRadius: Radius.card), behindContent: true)
        .contentShape(.rect(cornerRadius: Radius.card))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the task")
        .accessibilityIdentifier("search-task")
    }

    private var matchingSubtasks: [String] {
        guard !terms.isEmpty else { return [] }
        return document.subtasks.filter { !SearchText.matchRanges(of: terms, in: $0).isEmpty }.prefix(3).map { $0 }
    }
}

/// "Sat 25 Oct 2025" for a floating day. Formatted to a String in GMT (DECISIONS 249).
enum SearchDateLine {
    static func text(_ raw: String?) -> String {
        guard let raw, let day = DayKey(rawValue: raw) else { return String(localized: "No date") }
        return day.utcDate.formatted(Date.FormatStyle(timeZone: .gmt).weekday(.abbreviated).day().month(.abbreviated).year())
    }
}
