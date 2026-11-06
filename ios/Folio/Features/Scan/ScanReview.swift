import SwiftUI

/// Checking a scan before it's saved (Batch J): the pages, the date found on them, the text.
struct ScanReview: View {
    @Bindable var model: ScanModel
    @Environment(DiaryStore.self) private var store

    var body: some View {
        Form {
            Section {
                ScrollView(.horizontal) {
                    HStack(spacing: Spacing.s) {
                        ForEach(Array(model.images.prefix(Entry.maximumPhotos).enumerated()), id: \.offset) { _, data in
                            if let image = UIImage(data: data) {
                                Image(uiImage: image).resizable().scaledToFill()
                                    .frame(width: 84, height: 112).clipShape(.rect(cornerRadius: 12))
                                    .accessibilityLabel("Scanned page")
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
                if model.droppedPages > 0 {
                    Text("An entry keeps 10 photos; the last \(model.droppedPages) pages are left out — their text is kept.")
                        .folioFont(.caption).foregroundStyle(.inkSecondary)
                }
            } header: {
                Text("^[\(model.images.count) page](inflect: true)")
            }
            Section {
                DatePicker("Day", selection: dayBinding, in: ...store.today.adding(days: 1).utcDate, displayedComponents: .date)
                    .environment(\.timeZone, .gmt)
                if let suggested = model.suggestedDay {
                    Label {
                        Text("Found on the page: \(suggested.utcDate.formatted(Date.FormatStyle(timeZone: .gmt).day().month(.wide).year()))")
                    } icon: { Image(systemName: "text.viewfinder") }
                    .folioFont(.caption)
                    .foregroundStyle(.inkSecondary)
                    if model.day != suggested {
                        Button("Use the date on the page") { model.day = suggested }.tint(.accentStrong)
                    }
                }
            } footer: {
                if model.suggestedDay == nil { Text("No date found on the page. Pick the day it was written.") }
            }
            Section {
                TextEditor(text: $model.text)
                    .font(.system(.body, design: .serif))
                    .frame(minHeight: 220)
                    .accessibilityLabel("Text read from the page")
            } header: {
                Text("Text")
            } footer: {
                Text(model.text.isEmpty ? "No text found. The scan is still kept as a photo." : "Read on your iPhone. Fix anything it got wrong.")
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var dayBinding: Binding<Date> {
        Binding { model.day.utcDate } set: { model.day = DayKey(date: $0, calendar: DayKey.arithmeticCalendar) }
    }
}
