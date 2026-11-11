import SwiftUI

/// "October 2026": month in `title1`, year in `title2` secondary, with a chevron.
/// The month blurs in and the year rolls with `numericText` (SPEC §3.6).
struct MonthTitle: View {
    let month: MonthKey

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // Batch O: "September" with the Today pill showing didn't fit a 402-pt iPhone even at
        // 70 % and was cut to "Septe…"; the short name ("Sept") is the fallback. VoiceOver reads the
        // full name from the button's label.
        ViewThatFits(in: .horizontal) {
            title(.wide)
            title(.abbreviated)
        }
    }

    private func title(_ width: Date.FormatStyle.Symbol.Month) -> some View {
        // At accessibility sizes the month and year stack instead of truncating.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Spacing.xs))
        return layout {
            Text(month.firstDay.utcDate.formatted(Date.FormatStyle(timeZone: .gmt).month(width)))
                .folioFont(.title1)
                .foregroundStyle(.ink)
                .id(month.id)
                .transition(reduceMotion ? AnyTransition.opacity : AnyTransition(.blurReplace))
            Text(month.year, format: .number.grouping(.never))
                .folioFont(.title2)
                .foregroundStyle(.inkSecondary)
                .contentTransition(.numericText(value: Double(month.year)))
            Image(systemName: "chevron.down")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.inkSecondary)
                .accessibilityHidden(true)
        }
        .animation(FolioMotion.standard(reduceMotion: reduceMotion), value: month)
        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
        .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.85)
    }
}
