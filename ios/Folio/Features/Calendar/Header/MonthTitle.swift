import SwiftUI

/// "October 2026": month in `title1`, year in `title2` secondary, with a chevron.
/// The month blurs in and the year rolls with `numericText` (SPEC §3.6).
struct MonthTitle: View {
    let month: MonthKey

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // At accessibility sizes the month and year stack instead of truncating.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Spacing.xs))
        layout {
            Text(month.firstDay.utcDate.formatted(Date.FormatStyle(timeZone: .gmt).month(.wide)))
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
        .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.7)
    }
}
