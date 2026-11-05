import Foundation
import SwiftData

/// One square in Year in Pixels (Batch J).
struct YearPixel: Equatable {
    var entryIDs: [UUID] = []
    /// The day's latest set mood.
    var mood: Mood?
    /// The first page's category with one.
    var categoryID: UUID?
}

extension DiaryStore {
    /// Every written day of `year`, by "YYYY-MM-DD". One fetch per year (≤ a few hundred rows).
    func yearPixels(_ year: Int) -> [String: YearPixel] {
        _ = revision
        let prefix = String(format: "%04d-", year)
        let entries = fetch(FetchDescriptor<Entry>(
            predicate: #Predicate { $0.dayKey.starts(with: prefix) && !$0.isTombstone && $0.trashedAt == nil }
        )).sorted(by: Self.entryOrder)
        var pixels: [String: YearPixel] = [:]
        for entry in entries {
            var pixel = pixels[entry.dayKey] ?? YearPixel()
            pixel.entryIDs.append(entry.id)
            if let mood = entry.mood.flatMap(Mood.init(rawValue:)) { pixel.mood = mood }
            if pixel.categoryID == nil { pixel.categoryID = entry.categoryID }
            pixels[entry.dayKey] = pixel
        }
        return pixels
    }

    /// The first year with a page, for Year in Pixels' range.
    var firstYearWritten: Int? {
        var descriptor = FetchDescriptor<Entry>(predicate: #Predicate { !$0.isTombstone && $0.trashedAt == nil },
                                                sortBy: [SortDescriptor(\.dayKey)])
        descriptor.fetchLimit = 1
        return fetch(descriptor).first?.day?.year
    }
}
