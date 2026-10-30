#if DEBUG
import Foundation
import SwiftData

/// Realistic sample data (SPEC §5): ~40 entries across three years, some with photos,
/// 25 tasks and 6 categories, all relative to today so the calendar always has content.
/// Load with `-FolioSampleData YES`, or from the DEBUG menu.
enum PreviewData {
    struct CategorySeed {
        let name: String
        let color: CategoryColor
        let symbol: String
    }

    static let categories: [CategorySeed] = [
        CategorySeed(name: "Travel", color: .ocean, symbol: "airplane"),
        CategorySeed(name: "Family", color: .rose, symbol: "heart"),
        CategorySeed(name: "Work", color: .graphite, symbol: "briefcase"),
        CategorySeed(name: "Health", color: .sage, symbol: "figure.walk"),
        CategorySeed(name: "Ideas", color: .violet, symbol: "lightbulb"),
        CategorySeed(name: "Food", color: .sand, symbol: "fork.knife"),
    ]

    /// (days ago, title, body, category index or nil, minutes from midnight or nil, photo count)
    static let entries: [(Int, String, String, Int?, Int?, Int)] = [
        (0, "Morning swim", "The water was colder than I expected, but the light was **perfect**.", 3, 435, 1),
        (1, "Soup weather", "Made the leek and potato soup from Mum's card. _Still_ not as good as hers.", 5, 1140, 0),
        (2, "Train to Edinburgh", "Four hours of fields, rain and a very good book.\n- [x] book seats\n- [ ] find the café", 0, 560, 3),
        (3, "Quiet Sunday", "Did nothing at all, and it was the best day this month.", nil, nil, 0),
        (4, "Pitch went well", "They asked the right questions. ==Follow up on Thursday.==", 2, 1020, 0),
        (5, "Long walk", "12 km along the river. Saw a heron standing absolutely still.", 3, 700, 1),
        (7, "Grandad's birthday", "# 90 years\nHe told the story about the motorbike again. Everyone laughed anyway.", 1, 840, 2),
        (8, "An idea for the garden", "Raised beds along the south wall. Herbs nearest the kitchen door.", 4, nil, 0),
        (10, "Market day", "Bought far too many tomatoes.", 5, 600, 1),
        (12, "Rainy commute", "Forgot the umbrella. Again.", 2, 500, 0),
        (13, "Letter from Ana", "> I think of that summer every time it rains.\nI'll write back this weekend.", 1, nil, 0),
        (15, "First frost", "The car was white this morning. Scraped it with a library card.", nil, 455, 1),
        (18, "Book club", "Nobody finished it. We talked about it for two hours anyway.", 4, 1230, 0),
        (21, "Coast", "Wind so strong we could lean on it.", 0, 790, 2),
        (24, "New running shoes", "Ran 5 km without stopping for the first time.", 3, 390, 0),
        (28, "Dinner with the team", "Too much pasta, not enough sleep.", 2, 1260, 0),
        (33, "Moving the furniture", "The sofa fits by the window now. The room feels twice as big.", nil, nil, 0),
        (40, "Autumn colours", "Every tree in the park on fire at once.", nil, 900, 1),
        (47, "Started the sketchbook", "One drawing a day. Day one: a teacup.", 4, 1320, 0),
        (55, "Weekend in Bath", "Thermal baths at dusk. Steam rising into the dark.", 0, 1080, 2),
        (63, "Sister's news", "She's moving back to the city! Champagne.", 1, 1200, 0),
        (75, "Harvest", "The courgettes have taken over. Courgette everything for a week.", 5, 650, 1),
        (90, "Summer storm", "Thunder at 3 am. Counted the seconds like when I was small.", nil, 180, 0),
        (120, "Festival", "Danced until my feet hurt.", nil, 1350, 1),
        (150, "Exam results", "Passed. All that late reading paid off.", 2, 610, 0),
        (200, "Spring", "Blossom on every branch on the way to work.", nil, 480, 1),
        (250, "Snow day", "Schools closed. Built a very lopsided snowman.", 1, 720, 1),
        (300, "Lisbon", "Pastéis de nata for breakfast, lunch and dinner.", 0, 1000, 2),
        (365, "A year ago", "Started keeping this diary. Let's see how long it lasts.", nil, 1290, 0),
        (366, "Night before", "Bought a notebook. Feels like a promise.", nil, 1380, 0),
        (400, "Hospital visit", "Dad's knee surgery went well. Long day of waiting rooms.", 1, 960, 0),
        (450, "Mountains", "Summit at noon. Clouds below us like a sea.", 0, 720, 2),
        (500, "Lost my keys", "Found them in the fridge. Don't ask.", nil, 830, 0),
        (550, "Old friends", "Ten years since graduation. Nobody has changed and everyone has.", 1, 1250, 0),
        (600, "Recipe win", "Finally got the sourdough right.", 5, 640, 1),
        (700, "New job", "First day. Learned twelve names, remembered three.", 2, 1110, 0),
        (730, "Two years ago today", "Rain on the tent all night. Still smiling.", 0, 420, 1),
        (800, "Beach", "Sand in everything.", 0, 900, 1),
        (900, "Concert", "Front row. Ears still ringing.", nil, 1400, 0),
        (1000, "Winter", "Long dark evenings, candles and tea.", nil, 1080, 0),
    ]

    /// (day offset or nil for undated, title, notes, category index, completed)
    static let tasks: [(Int?, String, String?, Int?, Bool)] = [
        (0, "Post the letter to Ana", nil, 1, false),
        (0, "Book dentist", "Ask about the Thursday slot", 3, false),
        (0, "Water the herbs", nil, nil, true),
        (1, "Call Mum", nil, 1, false),
        (1, "Send invoice", "March and April together", 2, false),
        (-1, "Return library books", nil, nil, false),
        (-3, "Renew passport photo", "Booth at the station", 0, false),
        (-1, "Pay the gas bill", nil, nil, true),
        (-2, "Buy birthday card", nil, 1, true),
        (-4, "Finish slides", nil, 2, true),
        (-6, "Fix bike light", nil, nil, true),
        (-8, "Order seeds", "Tomatoes, basil, chard", 5, true),
        (-11, "Back up photos", nil, nil, true),
        (3, "Train tickets for Bath", nil, 0, false),
        (5, "Team lunch", nil, 2, false),
        (7, "Plant the bulbs", nil, 4, false),
        (10, "Dad's check-up", nil, 1, false),
        (14, "Car service", nil, nil, false),
        (nil, "Learn three Portuguese phrases", nil, 0, false),
        (nil, "Clear out the loft", "Start with the boxes by the hatch", nil, false),
        (nil, "Read 'The Overstory'", nil, 4, false),
        (nil, "Try the new running route", nil, 3, false),
        (nil, "Frame the Lisbon print", nil, nil, false),
        (2, "Bake bread for the weekend", nil, 5, false),
        (-2, "Reply to the landlord", nil, nil, true),
    ]

    /// Loads sample data unless the store already has content.
    @MainActor
    static func loadIfEmpty(into store: DiaryStore) {
        guard store.isEmpty else { return }
        load(into: store)
    }

    @MainActor
    static func load(into store: DiaryStore) {
        let today = store.today
        let categoryIDs = categories.compactMap { try? store.createCategory(name: $0.name, color: $0.color, symbol: $0.symbol).id }
        let processor = PhotoProcessor()
        for (index, seed) in entries.enumerated() {
            let (daysAgo, title, body, categoryIndex, minutes, photoCount) = seed
            guard let entry = try? store.createEntry(
                title: title, body: body, day: today.adding(days: -daysAgo), minutesFromMidnight: minutes,
                categoryID: categoryIndex.flatMap { categoryIDs.indices.contains($0) ? categoryIDs[$0] : nil }
            ) else { continue }
            for photoIndex in 0..<photoCount {
                if let jpeg = SampleImageRenderer.jpeg(seed: index * 3 + photoIndex),
                   let processed = try? processor.processSynchronously(jpeg) {
                    _ = try? store.addPhoto(processed, to: entry)
                }
            }
        }
        for (offset, title, notes, categoryIndex, done) in tasks {
            guard let task = try? store.createTask(
                title: title, notes: notes, day: offset.map { today.adding(days: $0) },
                categoryID: categoryIndex.flatMap { categoryIDs.indices.contains($0) ? categoryIDs[$0] : nil }
            ) else { continue }
            if done { store.setCompleted(task, true) }
        }
        // Batch I: a weekly task with a reminder, and one with subtasks.
        if let plants = try? store.createTask(title: "Water the plants", day: today.adding(days: 1), minutesFromMidnight: 8 * 60) {
            store.setRepeat(plants, RepeatRule(frequency: .weekly))
            store.setReminder(plants, ReminderTime(day: today.adding(days: 1), minutes: 8 * 60))
        }
        if let pack = try? store.createTask(title: "Pack for Lisbon", day: today.adding(days: 2)) {
            for (item, done) in [("Passport", true), ("Charger", false), ("Sun cream", false)] {
                if let sub = try? store.addSubtask(title: item, to: pack), done { store.setCompleted(sub, true) }
            }
        }
    }

    /// SPEC §15.1 performance check: 10,000 entries and 5,000 photos across ~30 years.
    /// Photos reuse one small processed image so generation stays quick.
    @MainActor
    static func loadStressData(into store: DiaryStore) {
        guard let jpeg = SampleImageRenderer.jpeg(seed: 1, width: 480, height: 360),
              let processed = try? PhotoProcessor().processSynchronously(jpeg) else { return }
        let today = store.today
        let context = store.context
        let now = AppClock.now
        for index in 0..<10_000 {
            let entry = Entry(title: "Entry \(index)", bodyMarkdown: "Stress test entry number \(index).",
                              day: today.adding(days: -(index % 11_000)), now: now)
            context.insert(entry)
            if index.isMultiple(of: 2) {
                context.insert(EntryPhoto(entry: entry, sortIndex: 0, processed: processed, now: now))
            }
            if index.isMultiple(of: 500) { try? context.save() }
        }
        try? context.save()
    }

    /// An in-memory store with sample data, for `#Preview`s.
    @MainActor
    static func previewStore() -> DiaryStore {
        let container = (try? FolioPersistence.makeContainer(inMemory: true))
            ?? { fatalError("In-memory SwiftData container could not be created") }()
        let store = DiaryStore(context: container.mainContext)
        load(into: store)
        return store
    }
}
#endif
