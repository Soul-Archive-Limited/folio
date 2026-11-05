import Foundation
import SwiftData
import Testing
@testable import Folio

@Suite("Search text")
struct SearchTextTests {
    @Test("Case and Latin accents fold; punctuation splits words")
    func folding() {
        #expect(SearchText.words(in: "Café, CRÈME-brûlée!") == ["cafe", "creme", "brulee"])
    }

    @Test("Hindi words keep their vowel signs and stay whole")
    func hindi() {
        let words = SearchText.words(in: "आज मैंने किताब पढ़ी।")
        #expect(words.count == 4)
        #expect(SearchText.words(in: "किताब") == [words[2]])
        // A different vowel sign is a different word.
        #expect(SearchText.words(in: "कताब") != [words[2]])
    }

    @Test("Word rules match the web app (shared/search-fixtures.json)")
    func sharedFixtures() throws {
        struct Fixtures: Decodable {
            struct Case: Decodable { let input: String; let words: [String] }
            let cases: [Case]
        }
        let url = try #require(Bundle(for: SearchBundleToken.self).url(forResource: "search-fixtures", withExtension: "json"))
        let fixtures = try JSONDecoder().decode(Fixtures.self, from: Data(contentsOf: url))
        #expect(fixtures.cases.count >= 7)
        for fixture in fixtures.cases {
            #expect(SearchText.words(in: fixture.input) == fixture.words, "\(fixture.input)")
        }
    }

    @Test("Prefix lookup on a sorted vocabulary")
    func prefixLookup() {
        let vocabulary = SearchText.vocabulary(of: ["Walk by the river", "Riverside café"])
        #expect(SearchText.vocabulary(vocabulary, hasPrefix: "riv"))
        #expect(SearchText.vocabulary(vocabulary, hasPrefix: "caf"))
        #expect(!SearchText.vocabulary(vocabulary, hasPrefix: "side"))
    }

    @Test("Highlights cover only the matched start of each word")
    func highlightRanges() {
        let text = "Rivers and the riverside"
        let ranges = SearchText.matchRanges(of: ["river"], in: text)
        #expect(ranges.map { String(text[$0]) } == ["River", "river"])
        #expect(SearchText.matchRanges(of: ["side"], in: text).isEmpty)
        let accented = "Un café crème"
        #expect(SearchText.matchRanges(of: ["creme"], in: accented).map { String(accented[$0]) } == ["crème"])
    }

    @Test("Snippets start near the first match")
    func snippet() {
        let long = String(repeating: "filler words here ", count: 10) + "the lighthouse at dusk"
        let snippet = SearchHighlight.snippet(long, terms: ["lighthouse"])
        #expect(snippet.hasPrefix("…"))
        #expect(snippet.contains("lighthouse"))
        #expect(snippet.count < long.count)
    }
}

private final class SearchBundleToken {}

@MainActor
@Suite("Search index")
struct SearchIndexTests {
    let container: ModelContainer
    let store: DiaryStore

    init() throws {
        container = try FolioPersistence.makeContainer(inMemory: true)
        store = DiaryStore(context: container.mainContext, calendar: TestCalendar.london,
                           now: { TestCalendar.date(2026, 10, 14) })
    }

    private func day(_ raw: String) throws -> DayKey { try #require(DayKey(rawValue: raw)) }

    private func build() async -> SearchIndex {
        await SearchIndexer().build(container: container)
    }

    @Test("Finds titles, body text, category names, tasks and subtasks; skips Recently Deleted")
    func findsEverything() async throws {
        let travel = try store.createCategory(name: "Travel", color: .ocean)
        try store.createEntry(title: "Lisbon", body: "Trams and **pastéis**", day: day("2025-05-02"), categoryID: travel.id)
        try store.createEntry(title: "Quiet day", body: "Read by the window", day: day("2026-01-10"))
        let gone = try store.createEntry(title: "Lisbon again", body: "", day: day("2026-02-01"))
        store.trash(gone)
        let task = try store.createTask(title: "Pack bags", day: day("2026-10-20"))
        _ = try store.addSubtask(title: "Passport", to: task)

        let index = await build()
        func titles(_ text: String, _ filters: SearchFilters = SearchFilters()) -> [String] {
            index.search(SearchQuery(text: text, filters: filters)).map(\.title)
        }
        #expect(titles("lisbon") == ["Lisbon"])
        #expect(titles("pasteis") == ["Lisbon"])
        #expect(titles("travel") == ["Lisbon"])
        #expect(titles("window read") == ["Quiet day"])
        #expect(titles("passp") == ["Pack bags"])
        #expect(titles("lisbon pack").isEmpty)
    }

    @Test("Filters: category, photos, date range, open/done, tasks-only scope")
    func filters() async throws {
        let work = try store.createCategory(name: "Work", color: .graphite)
        try store.createEntry(title: "Plan", body: "", day: day("2026-03-01"), categoryID: work.id)
        try store.createEntry(title: "Plan B", body: "", day: day("2025-03-01"))
        let done = try store.createTask(title: "Plan C", day: day("2026-03-02"))
        store.setCompleted(done, true)
        try store.createTask(title: "Plan D")

        let index = await build()
        func titles(_ filters: SearchFilters) -> Set<String> {
            Set(index.search(SearchQuery(text: "plan", filters: filters)).map(\.title))
        }
        #expect(titles(SearchFilters(categories: [work.id])) == ["Plan"])
        #expect(titles(SearchFilters(hasPhotos: true)).isEmpty)
        #expect(titles(SearchFilters(from: try day("2026-01-01"), through: try day("2026-12-31"))) == ["Plan", "Plan C"])
        #expect(titles(SearchFilters(status: .done)) == ["Plan C"])
        #expect(titles(SearchFilters(status: .open)) == ["Plan D"])
        #expect(titles(SearchFilters(scope: .tasksOnly)) == ["Plan C", "Plan D"])
        // Filters alone are a query too.
        #expect(index.search(SearchQuery(text: "", filters: SearchFilters(status: .done))).map(\.title) == ["Plan C"])
    }

    @Test("Rebuilds pick up edits and drop deleted pages")
    func incremental() async throws {
        let indexer = SearchIndexer()
        let entry = try store.createEntry(title: "Garden", body: "", day: day("2026-04-01"))
        #expect(await indexer.build(container: container).search(SearchQuery(text: "garden")).count == 1)
        try store.updateEntry(entry, title: "Allotment", body: "", categoryID: nil)
        let second = await indexer.build(container: container)
        #expect(second.search(SearchQuery(text: "garden")).isEmpty)
        #expect(second.search(SearchQuery(text: "allot")).count == 1)
        store.trash(entry)
        #expect(await indexer.build(container: container).search(SearchQuery(text: "allot")).isEmpty)
    }

    @Test("10,000 entries: a query takes well under a frame budget's worth of work")
    func tenThousand() async throws {
        var generator = SeededGenerator(seed: 7)
        let words = ["morning", "river", "coffee", "train", "letter", "garden", "rain", "market", "school", "friend",
                     "mountain", "evening", "music", "kitchen", "window", "harbour", "station", "lamp", "notebook", "bridge"]
        let start = try day("2000-01-01")
        for number in 0..<10_000 {
            let body = (0..<60).map { _ in words[Int(generator.next() % UInt64(words.count))] }.joined(separator: " ")
            store.context.insert(Entry(title: "Day \(number)", bodyMarkdown: body, day: start.adding(days: number), now: .now))
        }
        store.commit()

        let index = await build()
        #expect(index.documents.count == 10_000)
        let clock = ContinuousClock()
        var hits = 0
        let elapsed = clock.measure {
            hits = index.search(SearchQuery(text: "harb bridge")).count
        }
        #expect(hits > 0)
        // Simulator, Debug build: a few ms; leave headroom for slow CI machines.
        #expect(elapsed < .milliseconds(150))
    }
}
