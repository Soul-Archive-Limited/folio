import SwiftUI

/// One entry (SPEC §6.5): photos, date, category, title and body, plus Edit, Share and
/// a menu with Change date, Duplicate and Delete.
struct EntryDetailView: View {
    let entryID: UUID

    @Environment(DiaryStore.self) private var store
    @Environment(ToastCenter.self) private var toasts
    @Environment(\.newItemRequest) private var request
    @Environment(\.dismiss) private var dismiss
    @State private var showsDateSheet = false
    @State private var fullScreenPhoto: UUID?
    @State private var shareKind: EntryShareKind?

    var body: some View {
        Group {
            if let entry = store.entry(id: entryID) {
                content(entry)
            } else {
                EmptyStateView(systemImage: "doc", message: "This entry was deleted.")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background { AuraBackground() }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func content(_ entry: Entry) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.m) {
                let photos = entry.orderedPhotos
                if !photos.isEmpty {
                    PhotoCarousel(photoIDs: photos.map(\.id)) { fullScreenPhoto = $0 }
                }
                if let day = entry.day {
                    Text(dateLine(day: day, minutes: entry.minutesFromMidnight))
                        .folioFont(.caption)
                        .foregroundStyle(.inkSecondary)
                }
                if let category = store.category(id: entry.categoryID) {
                    CategoryTag(category: category)
                }
                if !entry.title.isEmpty {
                    Text(entry.title)
                        .folioFont(.title2)
                        .foregroundStyle(.ink)
                        .accessibilityAddTraits(.isHeader)
                }
                EntryBodyText(markdown: entry.bodyMarkdown, writingFont: writingFont)
                if let day = entry.day {
                    SameDayOtherYears(day: day, excluding: entry.id)
                }
            }
            .padding(.horizontal, Spacing.sideMargin)
            .padding(.bottom, Spacing.xxxl)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Edit", systemImage: "square.and.pencil") { request?.send(.editEntry(entry.id)) }
                // A small menu that says exactly what's shared (owner's iPhone test, Batch E).
                Menu("Share", systemImage: "square.and.arrow.up") { EntryShareMenu(entry: entry) { shareKind = $0 } }
                    .accessibilityIdentifier("entry.share")
                Menu("More", systemImage: "ellipsis") {
                    Button("Change date", systemImage: "calendar") { showsDateSheet = true }
                    Button("Duplicate", systemImage: "plus.square.on.square") { duplicate(entry) }
                    Divider()
                    Button("Delete", systemImage: "trash", role: .destructive) { delete(entry) }
                }
            }
        }
        .sheet(isPresented: $showsDateSheet) {
            ChangeDateSheet(entry: entry)
        }
        .entryShare($shareKind, entry: entry)
        .fullScreenCover(item: $fullScreenPhoto) { photoID in
            FullScreenPhotoViewer(photoIDs: entry.orderedPhotos.map(\.id), initial: photoID)
                .privacyCovered()
        }
    }

    private var writingFont: WritingFont {
        WritingFont(rawValue: store.settings().writingFont) ?? .newYork
    }

    private func dateLine(day: DayKey, minutes: Int?) -> String {
        let date = day.utcDate.formatted(Date.FormatStyle(timeZone: .gmt).weekday(.wide).day().month(.wide).year())
        guard let minutes else { return date }
        let calendar = store.calendar
        let time = calendar.date(byAdding: .minute, value: minutes, to: day.startDate(in: calendar)) ?? .now
        return "\(date) · \(time.formatted(.dateTime.hour().minute()))"
    }

    private func duplicate(_ entry: Entry) {
        if store.duplicate(entry) != nil {
            toasts.show(ToastMessage(text: "Entry duplicated", systemImage: "plus.square.on.square"))
        }
    }

    /// Moves the entry and its photos to Recently Deleted; no "Are you sure?" (SPEC §5.2).
    private func delete(_ entry: Entry) {
        store.trash(entry)
        dismiss()
        toasts.show(.movedToTrash { store.restoreFromTrash(entry) })
    }
}

extension UUID: @retroactive Identifiable {
    public var id: UUID { self }
}
