import SwiftUI
import UIKit

/// "Share as image → All pages": the entry as story-sized images (9:16, 1080 × 1920), numbered
/// 1/N, so a long entry is never cut off (owner's test, Batch I). Page 1 carries the photo,
/// date and title; the text flows across pages, split exactly by TextKit at the card's font.
enum EntryStoryPages {
    static let size = CGSize(width: 360, height: 640)
    static let padding: Double = 28
    /// Room for the "1/3 · Folio" footer.
    static let footer: Double = 36
    /// Height of page 1's header without a photo (date + title); the photo adds its own.
    static let headerHeight: Double = 92
    static let photoHeight: Double = 228

    static func bodyFont(_ writingFont: WritingFont) -> UIFont {
        let base = UIFont.systemFont(ofSize: 17)
        guard writingFont == .newYork, let serif = base.fontDescriptor.withDesign(.serif) else { return base }
        return UIFont(descriptor: serif, size: 17)
    }

    static var lineSpacing: Double { 5 }

    /// The text of each page.
    static func pages(content: EntryShareContent, hasPhoto: Bool, writingFont: WritingFont) -> [String] {
        let text = content.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
        let width = size.width - padding * 2
        let fullHeight = size.height - padding * 2 - footer
        let firstHeight = fullHeight - headerHeight - (hasPhoto ? photoHeight : 0)
        guard !text.isEmpty else { return [""] }

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        let storage = NSTextStorage(string: text, attributes: [.font: bodyFont(writingFont), .paragraphStyle: paragraph])
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)
        var pages: [String] = []
        var height = max(firstHeight, 40)
        var consumed = 0
        let nsText = text as NSString
        // A safety bound: 200 pages is ~60,000 characters at this size.
        while consumed < nsText.length, pages.count < 200 {
            let container = NSTextContainer(size: CGSize(width: width, height: height))
            container.lineFragmentPadding = 0
            layout.addTextContainer(container)
            let glyphs = layout.glyphRange(for: container)
            let range = layout.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
            guard range.length > 0 else { break }
            pages.append(nsText.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines))
            consumed = NSMaxRange(range)
            height = fullHeight
        }
        return pages.isEmpty ? [text] : pages
    }

    static func pageCount(content: EntryShareContent, hasPhoto: Bool, writingFont: WritingFont) -> Int {
        pages(content: content, hasPhoto: hasPhoto, writingFont: writingFont).count
    }

    /// PNG images of every page, at 3× (1080 × 1920).
    @MainActor
    static func images(content: EntryShareContent, photo: UIImage?, writingFont: WritingFont) -> [UIImage] {
        let texts = pages(content: content, hasPhoto: photo != nil, writingFont: writingFont)
        return texts.enumerated().compactMap { index, text in
            let page = EntryStoryPage(content: content, text: text, photo: index == 0 ? photo : nil, isFirst: index == 0,
                                      number: index + 1, total: texts.count, writingFont: writingFont)
            let renderer = ImageRenderer(content: page)
            renderer.scale = 3
            return renderer.uiImage
        }
    }
}

/// One story page, in the share card's style.
struct EntryStoryPage: View {
    let content: EntryShareContent
    let text: String
    let photo: UIImage?
    let isFirst: Bool
    let number: Int
    let total: Int
    let writingFont: WritingFont

    private static let ink = Color(red: 0x16 / 255, green: 0x16 / 255, blue: 0x1A / 255)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isFirst {
                if let photo {
                    Color.clear
                        .frame(height: EntryStoryPages.photoHeight - 16)
                        .overlay { Image(uiImage: photo).resizable().scaledToFill() }
                        .clipShape(.rect(cornerRadius: 18))
                        .padding(.bottom, 16)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(content.dateLine.uppercased())
                        .font(.system(size: 11, weight: .semibold)).tracking(0.8)
                        .foregroundStyle(Color(red: 0xB9 / 255, green: 0x44 / 255, blue: 0x1B / 255))
                    Text(content.title.isEmpty ? " " : content.title)
                        .font(.system(size: 24, weight: .bold)).lineLimit(2)
                        .foregroundStyle(Self.ink)
                }
                .frame(height: EntryStoryPages.headerHeight, alignment: .topLeading)
            }
            Text(text)
                .font(Font(EntryStoryPages.bodyFont(writingFont)))
                .lineSpacing(EntryStoryPages.lineSpacing)
                .foregroundStyle(Self.ink.opacity(0.82))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            HStack(spacing: 6) {
                Circle().fill(Color(red: 0xF0 / 255, green: 0x60 / 255, blue: 0x2A / 255)).frame(width: 6, height: 6)
                Text("Folio").font(.system(size: 11, weight: .semibold)).foregroundStyle(Self.ink.opacity(0.5))
                Spacer()
                if total > 1 {
                    Text("\(number)/\(total)").font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Self.ink.opacity(0.55))
                }
            }
            .frame(height: EntryStoryPages.footer, alignment: .bottom)
        }
        .padding(EntryStoryPages.padding)
        .frame(width: EntryStoryPages.size.width, height: EntryStoryPages.size.height, alignment: .topLeading)
        .background {
            ZStack {
                Color(red: 0xF5 / 255, green: 0xF3 / 255, blue: 0xEF / 255)
                Circle().fill(Color(red: 0xFF / 255, green: 0xB3 / 255, blue: 0x8F / 255).opacity(0.35))
                    .frame(width: 360).blur(radius: 80).offset(x: -150, y: -260)
                Circle().fill(Color(red: 0xA9 / 255, green: 0xC6 / 255, blue: 0xFF / 255).opacity(0.3))
                    .frame(width: 340).blur(radius: 80).offset(x: 160, y: 260)
            }
        }
        .environment(\.colorScheme, .light)
    }
}
