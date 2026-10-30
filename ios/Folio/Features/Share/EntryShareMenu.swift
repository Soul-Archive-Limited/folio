import SwiftUI

/// What the Share menu can send (owner's iPhone tests, Batches E and I).
enum EntryShareKind: String, Identifiable {
    /// Plain text (a `String`), which every app accepts — Messages, WhatsApp, Notes, Mail.
    case text
    case textAndPhotos
    /// One image card: date, first photo, title and opening lines.
    case singleCard
    /// The whole entry as numbered story-sized images (1/N…), so nothing is cut.
    case allPages

    var id: String { rawValue }
}

/// The ways to share an entry, as menu items (entry detail's Share menu and the cards'
/// long-press menu). The caller presents the share sheet with `.entryShare(_:entry:)`.
struct EntryShareMenu: View {
    let entry: Entry
    let onShare: (EntryShareKind) -> Void

    @Environment(DiaryStore.self) private var store

    var body: some View {
        let content = EntryShareContent(entry: entry)
        Button("Share as text", systemImage: "text.alignleft") { onShare(.text) }
        if !content.photoIDs.isEmpty {
            Button("Share text and photos", systemImage: "photo.on.rectangle") { onShare(.textAndPhotos) }
        }
        let pages = EntryStoryPages.pageCount(content: content, hasPhoto: !content.photoIDs.isEmpty, writingFont: writingFont)
        if pages > 1 || content.isCutOnCard {
            Menu("Share as image", systemImage: "rectangle.portrait.on.rectangle.portrait") {
                Button("Single card", systemImage: "rectangle.portrait") { onShare(.singleCard) }
                Button("All pages (\(pages))", systemImage: "rectangle.portrait.on.rectangle.portrait") { onShare(.allPages) }
            }
        } else {
            Button("Share as image", systemImage: "rectangle.portrait.on.rectangle.portrait") { onShare(.singleCard) }
        }
    }

    private var writingFont: WritingFont {
        WritingFont(rawValue: store.settings().writingFont) ?? .newYork
    }
}
