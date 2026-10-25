import Foundation

/// Chooses the launch greeting (SPEC §4.2): random from the time-of-day pool, never the
/// same as last launch, with special greetings 1-in-3 when they apply.
struct GreetingPicker {
    var calendar: Calendar = .current

    struct Choice: Equatable, Sendable {
        let id: String
        let text: String
    }

    func choose(
        now: Date,
        name: String?,
        lastID: String?,
        onThisDayYear: Int? = nil,
        using generator: inout some RandomNumberGenerator
    ) -> Choice {
        let specials = applicableSpecials(now: now, onThisDayYear: onThisDayYear).filter { $0.id != lastID }
        if !specials.isEmpty, Int.random(in: 0..<3, using: &generator) == 0,
           let special = specials.randomElement(using: &generator) {
            return Choice(id: special.id, text: special.text(name: name))
        }
        let hour = calendar.component(.hour, from: now)
        let pool = Greetings.pool(for: GreetingPeriod(hour: hour))
        let candidates = pool.filter { $0.id != lastID }
        let greeting = (candidates.isEmpty ? pool : candidates).randomElement(using: &generator) ?? pool[0]
        return Choice(id: greeting.id, text: greeting.text(name: name))
    }

    func applicableSpecials(now: Date, onThisDayYear: Int?) -> [Greeting] {
        let parts = calendar.dateComponents([.day, .month], from: now)
        var result: [Greeting] = []
        if parts.month == 1, parts.day == 1 {
            result.append(Greetings.newYear())
        } else if parts.day == 1 {
            let monthName = now.formatted(Date.FormatStyle(calendar: calendar).month(.wide))
            result.append(Greetings.firstOfMonth(monthName: monthName))
        }
        if let onThisDayYear {
            result.append(Greetings.onThisDay(year: onThisDayYear))
        }
        return result
    }
}
