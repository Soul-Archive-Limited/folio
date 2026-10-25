import Foundation
import Testing
@testable import Folio

@Suite("Greeting picker (SPEC §4.2)")
struct GreetingPickerTests {
    let picker = GreetingPicker(calendar: TestCalendar.london)

    @Test("Hours map to the right time-of-day band", arguments: [
        (4, GreetingPeriod.early), (6, .early), (7, .morning), (11, .morning), (12, .afternoon),
        (16, .afternoon), (17, .evening), (20, .evening), (21, .night), (23, .night), (0, .night), (3, .night),
    ])
    func periods(hour: Int, expected: GreetingPeriod) {
        #expect(GreetingPeriod(hour: hour) == expected)
    }

    @Test("Never repeats the previous launch's greeting")
    func noRepeat() {
        var generator = SeededGenerator(seed: 42)
        let now = TestCalendar.date(2026, 10, 14, 9)
        var last: String?
        for _ in 0..<200 {
            let choice = picker.choose(now: now, name: "Sam", lastID: last, using: &generator)
            #expect(choice.id != last)
            last = choice.id
        }
    }

    @Test("Morning greetings come from the morning pool and include the name")
    func morningPool() {
        var generator = SeededGenerator(seed: 7)
        let ids = Set(Greetings.morning.map(\.id))
        let choice = picker.choose(now: TestCalendar.date(2026, 10, 14, 8), name: "Sam", lastID: nil, using: &generator)
        #expect(ids.contains(choice.id))
        #expect(choice.text.contains("Sam"))
    }

    @Test("Without a name, the name and its comma are dropped")
    func unnamed() {
        for greeting in Greetings.early + Greetings.morning + Greetings.afternoon + Greetings.evening + Greetings.night {
            let text = greeting.text(name: nil)
            #expect(!text.contains(",."))
            #expect(!text.contains(" ."))
            #expect(!text.contains("  "))
            #expect(greeting.text(name: "   ") == text)
        }
        #expect(Greetings.morning[0].text(name: nil) == "Good morning.")
    }

    @Test("Specials apply on the 1st of the month, New Year's Day and on-this-day")
    func specials() {
        let first = picker.applicableSpecials(now: TestCalendar.date(2026, 11, 1), onThisDayYear: nil)
        #expect(first.map(\.id) == ["special.month"])
        #expect(first[0].text(name: nil) == "Hello, November.")

        let newYear = picker.applicableSpecials(now: TestCalendar.date(2027, 1, 1), onThisDayYear: 2024)
        #expect(newYear.map(\.id) == ["special.newyear", "special.onthisday"])
        #expect(newYear[1].text(name: nil) == "On this day in 2024, you wrote something.")

        #expect(picker.applicableSpecials(now: TestCalendar.date(2026, 10, 14), onThisDayYear: nil).isEmpty)
    }

    @Test("A special greeting is chosen about one launch in three")
    func specialFrequency() {
        var generator = SeededGenerator(seed: 1)
        let now = TestCalendar.date(2026, 11, 1, 9)
        let specials = (0..<3000).count { _ in
            picker.choose(now: now, name: nil, lastID: nil, using: &generator).id == "special.month"
        }
        #expect((850...1150).contains(specials))
    }
}
