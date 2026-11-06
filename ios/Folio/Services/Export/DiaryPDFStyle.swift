import UIKit

/// How the diary PDF looks (Batch J): paper, New York for writing, accent for dates — always the
/// light palette, since it's for paper and screens alike.
nonisolated enum DiaryPDFStyle {
    // Light tokens (Batch K): paper #F6F3EC, ink #17161C, accent text #303AC0 (Ink).
    static let paper = UIColor(red: 0.965, green: 0.953, blue: 0.925, alpha: 1)
    static let ink = UIColor(red: 0.090, green: 0.086, blue: 0.110, alpha: 1)
    static let secondary = UIColor(red: 0.090, green: 0.086, blue: 0.110, alpha: 0.6)
    static let accent = UIColor(red: 0.188, green: 0.227, blue: 0.753, alpha: 1)
    static let highlight = UIColor(red: 1, green: 0.85, blue: 0.55, alpha: 0.7)

    static func serif(_ size: CGFloat, _ weight: UIFont.Weight = .regular, italic: Bool = false) -> UIFont {
        var descriptor = UIFont.systemFont(ofSize: size, weight: weight).fontDescriptor.withDesign(.serif) ?? UIFont.systemFont(ofSize: size).fontDescriptor
        if italic, let slanted = descriptor.withSymbolicTraits(descriptor.symbolicTraits.union(.traitItalic)) { descriptor = slanted }
        return UIFont(descriptor: descriptor, size: size)
    }

    static func sans(_ size: CGFloat, _ weight: UIFont.Weight = .regular) -> UIFont { .systemFont(ofSize: size, weight: weight) }

    private static func paragraph(spacingBefore: CGFloat = 0, after: CGFloat = 4, indent: CGFloat = 0, align: NSTextAlignment = .natural,
                                  lineHeight: CGFloat = 1.38) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.paragraphSpacingBefore = spacingBefore
        style.paragraphSpacing = after
        style.headIndent = indent
        style.firstLineHeadIndent = indent
        style.alignment = align
        style.lineHeightMultiple = lineHeight
        if indent > 0 { style.tabStops = [NSTextTab(textAlignment: .left, location: indent)]; style.firstLineHeadIndent = 0 }
        return style
    }

    // MARK: Pages

    static func fillPaper() {
        paper.setFill()
        UIRectFill(CGRect(origin: .zero, size: DiaryPDF.pageSize))
    }

    static func drawCover(_ cover: DiaryPDF.Cover, from: DayKey, through: DayKey, entries: Int) {
        fillPaper()
        let width = DiaryPDF.pageSize.width
        let side: CGFloat = 104
        let avatarRect = CGRect(x: (width - side) / 2, y: 150, width: side, height: side)
        if let data = cover.avatarPhoto, let image = UIImage(data: data) {
            UIBezierPath(ovalIn: avatarRect).addClip()
            image.draw(in: avatarRect)
            UIGraphicsGetCurrentContext()?.resetClip()
        } else if let number = cover.avatarNumber, let image = UIImage(named: FolioAvatar.assetName(number)) {
            image.draw(in: avatarRect)
        } else {
            accent.withAlphaComponent(0.15).setFill()
            UIBezierPath(ovalIn: avatarRect).fill()
            let initial = cover.name.first.map(String.init)?.uppercased() ?? "F"
            centered(initial, font: serif(46, .bold), color: accent, y: avatarRect.midY - 30)
        }
        let title = cover.name.isEmpty ? String(localized: "My diary") : String(localized: "\(cover.name)’s diary")
        centered(title, font: serif(30, .bold), color: ink, y: 290)
        let style = Date.FormatStyle(timeZone: .gmt).month(.wide).year()
        centered("\(from.utcDate.formatted(style)) – \(through.utcDate.formatted(style))", font: serif(16, italic: true), color: secondary, y: 336)
        centered(pagesLabel(entries), font: sans(11, .medium), color: secondary, y: 362)
        let mark = CGRect(x: (width - 28) / 2, y: DiaryPDF.pageSize.height - 108, width: 28, height: 28)
        UIImage(named: "AppMark")?.draw(in: mark)
        centered("Folio", font: sans(10, .semibold), color: accent, y: DiaryPDF.pageSize.height - 70)
    }

    /// "3 pages", inflected.
    static func pagesLabel(_ count: Int) -> String {
        String(AttributedString(localized: "^[\(count) page](inflect: true)").characters)
    }

    /// The month's opening, at the top of its first page: a big month name, the year in accent,
    /// how many pages, and a hairline.
    static func monthHeading(_ month: MonthKey, pages: Int) -> NSAttributedString {
        let text = NSMutableAttributedString()
        let name = month.firstDay.utcDate.formatted(Date.FormatStyle(timeZone: .gmt).month(.wide))
        text.append(NSAttributedString(string: name + " ", attributes: [.font: serif(30, .bold), .foregroundColor: ink,
                                                                        .paragraphStyle: paragraph(after: 0, lineHeight: 1)]))
        text.append(NSAttributedString(string: String(month.year) + "\n", attributes: [.font: serif(20, italic: true), .foregroundColor: accent,
                                                                                    .paragraphStyle: paragraph(after: 0, lineHeight: 1)]))
        text.append(NSAttributedString(string: pagesLabel(pages).uppercased() + "\n", attributes: [
            .font: sans(7.5, .semibold), .foregroundColor: secondary, .kern: 0.8, .paragraphStyle: paragraph(spacingBefore: 4, after: 2)]))
        text.append(NSAttributedString(string: "\u{00A0}\n", attributes: [
            .font: sans(2), .strikethroughStyle: NSUnderlineStyle.single.rawValue, .strikethroughColor: secondary.withAlphaComponent(0.25),
            .paragraphStyle: paragraph(after: 6)]))
        return text
    }

    static func drawFooter(page: Int, month: MonthKey) {
        let label = month.firstDay.utcDate.formatted(Date.FormatStyle(timeZone: .gmt).month(.abbreviated).year())
        let y = DiaryPDF.pageSize.height - 34
        (label as NSString).draw(at: CGPoint(x: DiaryPDF.margins.left, y: y), withAttributes: [.font: sans(8, .medium), .foregroundColor: secondary])
        let number = "\(page)" as NSString
        let attributes: [NSAttributedString.Key: Any] = [.font: sans(8, .medium), .foregroundColor: secondary]
        let size = number.size(withAttributes: attributes)
        number.draw(at: CGPoint(x: DiaryPDF.pageSize.width - DiaryPDF.margins.right - size.width, y: y), withAttributes: attributes)
    }

    private static func centered(_ text: String, font: UIFont, color: UIColor, y: CGFloat) {
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let size = (text as NSString).size(withAttributes: attributes)
        (text as NSString).draw(at: CGPoint(x: (DiaryPDF.pageSize.width - size.width) / 2, y: y), withAttributes: attributes)
    }

    // MARK: A day

    static func day(_ day: DiaryPDF.Day, width: CGFloat) -> NSAttributedString {
        let text = NSMutableAttributedString()
        let dateLine = day.day.utcDate.formatted(Date.FormatStyle(timeZone: .gmt).weekday(.wide).day().month(.wide)).uppercased()
        for (index, entry) in day.entries.enumerated() {
            var line = index == 0 ? dateLine : ""
            if let minutes = entry.minutes { line += (line.isEmpty ? "" : " · ") + String(format: "%02d:%02d", minutes / 60, minutes % 60) }
            if let mood = entry.mood.flatMap(Mood.init(rawValue:)) { line += (line.isEmpty ? "" : " · ") + mood.title.uppercased() }
            if !line.isEmpty {
                text.append(NSAttributedString(string: line + "\n", attributes: [
                    .font: sans(8.5, .semibold), .foregroundColor: accent, .kern: 0.8,
                    .paragraphStyle: paragraph(spacingBefore: 14, after: 4)]))
            }
            if !entry.title.isEmpty {
                text.append(NSAttributedString(string: entry.title + "\n", attributes: [
                    .font: serif(17, .bold), .foregroundColor: ink, .paragraphStyle: paragraph(after: 6, lineHeight: 1.15)]))
            }
            text.append(body(entry.markdown))
            for data in entry.photos {
                guard let image = DiaryPDF.printImage(data) else { continue }
                let scale = min(width / image.size.width, 250 / image.size.height, 1)
                let attachment = NSTextAttachment(image: image)
                attachment.bounds = CGRect(x: 0, y: 0, width: image.size.width * scale, height: image.size.height * scale)
                text.append(NSAttributedString(attachment: attachment))
                text.append(NSAttributedString(string: "\n", attributes: [.paragraphStyle: paragraph(spacingBefore: 4, after: 8, align: .center)]))
            }
        }
        if !day.tasks.isEmpty {
            if day.entries.isEmpty {
                text.append(NSAttributedString(string: dateLine + "\n", attributes: [
                    .font: sans(8.5, .semibold), .foregroundColor: accent, .kern: 0.8, .paragraphStyle: paragraph(spacingBefore: 14, after: 4)]))
            }
            text.append(NSAttributedString(string: String(localized: "TASKS") + "\n", attributes: [
                .font: sans(7.5, .semibold), .foregroundColor: secondary, .kern: 0.8, .paragraphStyle: paragraph(spacingBefore: 6, after: 2)]))
            for task in day.tasks {
                var attributes: [NSAttributedString.Key: Any] = [.font: serif(11), .foregroundColor: task.done ? secondary : ink,
                                                                  .paragraphStyle: paragraph(after: 1, indent: 16)]
                if task.done { attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
                text.append(NSAttributedString(string: (task.done ? "☑\t" : "☐\t") + task.title + "\n", attributes: attributes))
            }
        }
        text.append(NSAttributedString(string: "·   ·   ·\n", attributes: [
            .font: sans(9), .foregroundColor: secondary.withAlphaComponent(0.4), .paragraphStyle: paragraph(spacingBefore: 8, after: 6, align: .center)]))
        return text
    }

    /// Folio Markdown (SPEC §5.1) as print text: every style the editor allows.
    static func body(_ markdown: String) -> NSAttributedString {
        let text = NSMutableAttributedString()
        var number = 0
        for block in MarkdownCodec.document(from: markdown).blocks {
            number = block.kind == .numbered ? number + 1 : 0
            var base: [NSAttributedString.Key: Any] = [.font: serif(11.5), .foregroundColor: ink, .paragraphStyle: paragraph()]
            var prefix = ""
            switch block.kind {
            case .paragraph: break
            case .heading:
                base[.font] = serif(14, .bold)
                base[.paragraphStyle] = paragraph(spacingBefore: 6, after: 3)
            case .bullet: prefix = "•\t"; base[.paragraphStyle] = paragraph(indent: 14)
            case .numbered: prefix = "\(number).\t"; base[.paragraphStyle] = paragraph(indent: 16)
            case .checklist(let checked): prefix = checked ? "☑\t" : "☐\t"; base[.paragraphStyle] = paragraph(indent: 16)
            case .quote:
                base[.font] = serif(11.5, italic: true)
                base[.foregroundColor] = secondary
                base[.paragraphStyle] = paragraph(indent: 14)
                prefix = "\t"
            }
            text.append(NSAttributedString(string: prefix, attributes: base))
            for run in block.runs {
                var attributes = base
                let bold = run.styles.contains(.bold) || block.kind == .heading
                let italic = run.styles.contains(.italic) || block.kind == .quote
                if bold || italic { attributes[.font] = serif(block.kind == .heading ? 14 : 11.5, bold ? .bold : .regular, italic: italic) }
                if run.styles.contains(.underline) { attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue }
                if run.styles.contains(.strikethrough) { attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
                if run.styles.contains(.highlight) { attributes[.backgroundColor] = highlight }
                text.append(NSAttributedString(string: run.text, attributes: attributes))
            }
            text.append(NSAttributedString(string: "\n", attributes: base))
        }
        return text
    }
}
