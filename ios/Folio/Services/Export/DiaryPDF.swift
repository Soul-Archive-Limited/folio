import ImageIO
import SwiftData
import UIKit

/// The diary as a typeset PDF (Batch J): a cover (name, picture, range), a divider page for
/// each month, then every page of the diary in order — date, mood, title, formatted text,
/// photos — with the day's tasks if asked. Made on the device, off the main thread, with
/// progress; nothing leaves the device until the person shares it.
nonisolated enum DiaryPDF {
    struct Options: Sendable, Equatable {
        var from: DayKey
        var through: DayKey
        var includesTasks = true
        var includesPhotos = true
    }

    struct Result: Sendable {
        let url: URL
        let pageCount: Int
        let entryCount: Int
    }

    enum Failure: Error { case nothingInRange, cancelled }

    // A5, the size of a paper diary.
    static let pageSize = CGSize(width: 419.53, height: 595.28)
    static let margins = UIEdgeInsets(top: 48, left: 46, bottom: 54, right: 46)
    static var textRect: CGRect {
        CGRect(x: margins.left, y: margins.top, width: pageSize.width - margins.left - margins.right,
               height: pageSize.height - margins.top - margins.bottom)
    }

    // MARK: Gathering (on a background context)

    struct Day: Sendable {
        let day: DayKey
        var entries: [EntryPage] = []
        var tasks: [(title: String, done: Bool)] = []
    }

    struct EntryPage: Sendable {
        let title: String
        let markdown: String
        let minutes: Int?
        let mood: Int?
        let photos: [Data]
    }

    struct Cover: Sendable {
        let name: String
        let avatarNumber: Int?
        let avatarPhoto: Data?
    }

    static func gather(container: ModelContainer, options: Options) -> (cover: Cover, months: [(MonthKey, [Day])]) {
        let context = ModelContext(container)
        let from = options.from.rawValue
        let through = options.through.rawValue
        let entries = (try? context.fetch(FetchDescriptor<Entry>(predicate: #Predicate {
            $0.dayKey >= from && $0.dayKey <= through && !$0.isTombstone && $0.trashedAt == nil
        }))) ?? []
        var days: [DayKey: Day] = [:]
        for entry in entries.sorted(by: DiaryStore.entryOrder) {
            guard let day = entry.day else { continue }
            let photos = options.includesPhotos ? entry.orderedPhotos.map { $0.displayData ?? $0.imageData } : []
            days[day, default: Day(day: day)].entries.append(
                EntryPage(title: entry.title, markdown: entry.bodyMarkdown, minutes: entry.minutesFromMidnight, mood: entry.mood, photos: photos))
        }
        if options.includesTasks {
            // Compared in Swift: optional comparisons inside #Predicate don't translate to SQL safely.
            let tasks = ((try? context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate {
                $0.dayKey != nil && !$0.isTombstone && $0.trashedAt == nil && $0.parentID == nil
            }))) ?? []).filter { ($0.dayKey ?? "") >= from && ($0.dayKey ?? "") <= through }
            for task in tasks.sorted(by: DiaryStore.taskOrder) {
                guard let day = task.day else { continue }
                days[day, default: Day(day: day)].tasks.append((task.title, task.isCompleted))
            }
        }
        let id = UserSettings.singletonID
        var settingsFetch = FetchDescriptor<UserSettings>(predicate: #Predicate { $0.id == id })
        settingsFetch.fetchLimit = 1
        let settings = try? context.fetch(settingsFetch).first
        let cover = Cover(name: settings?.displayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                          avatarNumber: FolioAvatar.number(from: settings?.avatar),
                          avatarPhoto: settings?.avatar == "photo" ? settings?.avatarPhoto : nil)
        let months = Dictionary(grouping: days.values, by: \.day.monthKey)
            .sorted { $0.key < $1.key }
            .map { ($0.key, $0.value.sorted { $0.day < $1.day }) }
        return (cover, months)
    }

    // MARK: Rendering

    static func render(container: ModelContainer, options: Options, progress: @Sendable (Double) -> Void) throws -> Result {
        let (cover, months) = gather(container: container, options: options)
        let entryCount = months.reduce(0) { $0 + $1.1.reduce(0) { $0 + $1.entries.count } }
        guard !months.isEmpty else { throw Failure.nothingInRange }
        let units = Double(max(months.reduce(0) { $0 + $1.1.count }, 1))
        var done = 0.0

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [kCGPDFContextTitle as String: String(localized: "Folio diary"), kCGPDFContextCreator as String: "Folio"]
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize), format: format)
        var pageCount = 0
        var cancelled = false
        let data = renderer.pdfData { pdf in
            pdf.beginPage()
            pageCount += 1
            DiaryPDFStyle.drawCover(cover, from: options.from, through: options.through, entries: entryCount)
            for (month, days) in months {
                if Task.isCancelled { cancelled = true; return }
                // Every month opens a new page with its heading.
                let text = NSMutableAttributedString(attributedString: DiaryPDFStyle.monthHeading(month, pages: days.reduce(0) { $0 + $1.entries.count }))
                for day in days {
                    text.append(DiaryPDFStyle.day(day, width: textRect.width))
                    done += 1
                    progress(min(done / units, 0.99))
                }
                pageCount += flow(text, in: pdf, startingAt: pageCount, month: month)
            }
        }
        if cancelled { throw Failure.cancelled }
        let years = options.from.year == options.through.year ? String(options.from.year)
            : "\(String(options.from.year))–\(String(options.through.year))"
        let name = String(localized: "Folio Diary \(years)")
        let url = URL.temporaryDirectory.appending(path: "\(name).pdf")
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        progress(1)
        return Result(url: url, pageCount: pageCount, entryCount: entryCount)
    }

    /// Lays `text` over as many pages as it needs (TextKit: one container per page).
    private static func flow(_ text: NSAttributedString, in pdf: UIGraphicsPDFRendererContext, startingAt page: Int, month: MonthKey) -> Int {
        let storage = NSTextStorage(attributedString: text)
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)
        var pages = 0
        var location = 0
        while location < layout.numberOfGlyphs {
            let container = NSTextContainer(size: textRect.size)
            container.lineFragmentPadding = 0
            layout.addTextContainer(container)
            let range = layout.glyphRange(for: container)
            guard range.length > 0 else { break }
            pdf.beginPage()
            pages += 1
            DiaryPDFStyle.fillPaper()
            layout.drawBackground(forGlyphRange: range, at: textRect.origin)
            layout.drawGlyphs(forGlyphRange: range, at: textRect.origin)
            DiaryPDFStyle.drawFooter(page: page + pages, month: month)
            location = NSMaxRange(range)
        }
        return pages
    }

    /// A photo made small enough for print (≤ 1000 px), as an image the text can hold.
    static func printImage(_ data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceThumbnailMaxPixelSize: 1000,
              ] as CFDictionary) else { return nil }
        guard let jpeg = UIImage(cgImage: image).jpegData(compressionQuality: 0.72) else { return nil }
        return UIImage(data: jpeg)
    }
}
