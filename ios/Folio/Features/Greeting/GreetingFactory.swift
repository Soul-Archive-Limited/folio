import Foundation

/// Builds the launch greeting, applying the skip-on-quick-resume rule and remembering the
/// chosen greeting so the next launch picks a different one.
struct GreetingFactory {
    let defaults: UserDefaults
    var picker = GreetingPicker()

    func makeIfNeeded(now: Date, summary: GreetingSummary, force: Bool = false) -> GreetingIntroModel? {
        let lastBackground = defaults.object(forKey: PreferenceKeys.lastBackgroundAt) as? Date
        guard force || GreetingLaunchPolicy.shouldShow(now: now, lastBackgroundAt: lastBackground) else {
            return nil
        }
        var generator = SystemRandomNumberGenerator()
        let choice = picker.choose(
            now: now,
            name: defaults.string(forKey: PreferenceKeys.displayName),
            lastID: defaults.string(forKey: PreferenceKeys.lastGreetingID),
            onThisDayYear: summary.onThisDayYear,
            using: &generator
        )
        defaults.set(choice.id, forKey: PreferenceKeys.lastGreetingID)
        let quietLine = Greetings.quietSummaries.randomElement(using: &generator) ?? Greetings.quietSummaries[0]
        return GreetingIntroModel(greeting: choice.text, summary: summary, quietLine: quietLine)
    }
}
