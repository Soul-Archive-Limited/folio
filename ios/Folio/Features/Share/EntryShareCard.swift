import SwiftUI

/// "Share as image": one entry as a card in Folio's style — paper background, aura, the date
/// as typography, the first photo, the title and the opening lines (SPEC §3.1). Rendered at a
/// fixed 1080 px width with `ImageRenderer`, always in light appearance.
struct EntryShareCard: View {
    let content: EntryShareContent
    let photo: UIImage?
    let writingFont: WritingFont

    static let width: Double = 360

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let photo {
                Color.clear
                    .aspectRatio(4 / 3, contentMode: .fit)
                    .overlay { Image(uiImage: photo).resizable().scaledToFill() }
                    .clipShape(.rect(cornerRadius: 18))
            }
            Text(content.dateLine.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Color(red: 0xB9 / 255, green: 0x44 / 255, blue: 0x1B / 255))
            if !content.title.isEmpty {
                Text(content.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color(red: 0x16 / 255, green: 0x16 / 255, blue: 0x1A / 255))
            }
            if !content.openingLines.isEmpty {
                Text(content.openingLines)
                    .font(writingFont == .newYork ? .system(size: 15, design: .serif) : .system(size: 15))
                    .lineSpacing(4)
                    .foregroundStyle(Color(red: 0x16 / 255, green: 0x16 / 255, blue: 0x1A / 255).opacity(0.78))
                    .lineLimit(8)
            }
            HStack(spacing: 6) {
                Circle().fill(Color(red: 0xF0 / 255, green: 0x60 / 255, blue: 0x2A / 255)).frame(width: 6, height: 6)
                Text("Folio").font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(red: 0x16 / 255, green: 0x16 / 255, blue: 0x1A / 255).opacity(0.5))
            }
            .padding(.top, 4)
        }
        .padding(22)
        .frame(width: Self.width, alignment: .leading)
        .background {
            ZStack {
                Color(red: 0xF5 / 255, green: 0xF3 / 255, blue: 0xEF / 255)
                Circle().fill(Color(red: 0xFF / 255, green: 0xB3 / 255, blue: 0x8F / 255).opacity(0.35))
                    .frame(width: 320).blur(radius: 70).offset(x: -140, y: -160)
                Circle().fill(Color(red: 0xA9 / 255, green: 0xC6 / 255, blue: 0xFF / 255).opacity(0.3))
                    .frame(width: 300).blur(radius: 70).offset(x: 160, y: 200)
            }
        }
        .environment(\.colorScheme, .light)
    }

    /// The card as PNG data at 3× (1080 px wide).
    @MainActor
    static func png(content: EntryShareContent, photo: UIImage?, writingFont: WritingFont) -> Data? {
        let renderer = ImageRenderer(content: EntryShareCard(content: content, photo: photo, writingFont: writingFont))
        renderer.scale = 3
        return renderer.uiImage?.pngData()
    }
}

#if DEBUG
#Preview {
    EntryShareCard(content: EntryShareContent(title: "Train to Edinburgh", dateLine: "Sunday 25 October 2026",
                                              plainText: "Four hours of fields, rain and a very good book."),
                   photo: nil, writingFont: .newYork)
}
#endif
