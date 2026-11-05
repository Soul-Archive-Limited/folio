import SwiftUI

/// Year in Pixels (Batch J): every day of a year as a square, coloured by mood or category.
/// Years swipe sideways; a tap opens the day. Counts nothing in a row — no streaks.
struct YearInPixelsView: View {
    @Bindable var model: JournalModel
    @Environment(DiaryStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visibleYear: Int?

    var body: some View {
        let current = store.today.year
        let years = Array((store.firstYearWritten ?? current)...current)
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                Text(String(visibleYear ?? current))
                    .font(.system(size: 34, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(FolioMotion.standard(reduceMotion: reduceMotion), value: visibleYear)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Picker("Colour by", selection: $model.pixelsByMood) {
                    Text("Mood").tag(true)
                    Text("Category").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            .padding(.horizontal, Spacing.sideMargin)

            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 0) {
                    ForEach(years, id: \.self) { year in
                        YearPixelGrid(year: year, byMood: model.pixelsByMood, onOpen: open)
                            .padding(.horizontal, Spacing.sideMargin)
                            .containerRelativeFrame(.horizontal)
                            .id(year)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $visibleYear)
            .onAppear { if visibleYear == nil { visibleYear = current } }

            PixelLegend(byMood: model.pixelsByMood)
                .padding(.horizontal, Spacing.sideMargin)
        }
    }

    /// One page opens in place; a day with several goes to the calendar.
    private func open(_ pixel: YearPixel, day: DayKey) {
        if pixel.entryIDs.count == 1, let id = pixel.entryIDs.first {
            model.path.append(id)
        } else {
            model.openDay = day
        }
    }
}

/// One year: 12 month columns × 31 day rows.
struct YearPixelGrid: View {
    let year: Int
    let byMood: Bool
    let onOpen: (YearPixel, DayKey) -> Void
    @Environment(DiaryStore.self) private var store

    /// J F M A …, in the person's language.
    private static let monthLetters: [String] = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = .current
        return calendar.veryShortStandaloneMonthSymbols
    }()

    var body: some View {
        let pixels = store.yearPixels(year)
        let colors = Dictionary(uniqueKeysWithValues: store.categories().map { ($0.id, $0.color.color) })
        let today = store.today
        Grid(horizontalSpacing: 3, verticalSpacing: 3) {
            GridRow {
                Text("").gridColumnAlignment(.trailing)
                ForEach(0..<12, id: \.self) { month in
                    Text(Self.monthLetters[month]).font(.caption2.weight(.semibold)).foregroundStyle(.inkSecondary)
                }
            }
            ForEach(1...31, id: \.self) { dayNumber in
                GridRow {
                    Text(dayNumber % 5 == 0 || dayNumber == 1 ? "\(dayNumber)" : "")
                        .font(.system(size: 9, weight: .medium).monospacedDigit())
                        .foregroundStyle(.inkTertiary)
                        .frame(width: 14, alignment: .trailing)
                    ForEach(1...12, id: \.self) { month in
                        cell(day: DayKey(year: year, month: month, day: dayNumber), pixels: pixels, colors: colors, today: today)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Year in Pixels, \(String(year))"))
    }

    @ViewBuilder
    private func cell(day: DayKey?, pixels: [String: YearPixel], colors: [UUID: Color], today: DayKey) -> some View {
        let shape = RoundedRectangle(cornerRadius: 3.5, style: .continuous)
        if let day {
            let pixel = pixels[day.rawValue]
            let fill: Color = {
                guard let pixel else { return day > today ? Color.ink.opacity(0.03) : Color.ink.opacity(0.07) }
                if byMood { return pixel.mood?.color ?? Color.ink.opacity(0.22) }
                return pixel.categoryID.flatMap { colors[$0] } ?? Color.ink.opacity(0.22)
            }()
            Button {
                if let pixel { onOpen(pixel, day) }
            } label: {
                shape.fill(fill)
                    .overlay { if day == today { shape.strokeBorder(.ember, lineWidth: 1.5) } }
                    .frame(maxWidth: .infinity)
                    .frame(height: 17)
            }
            .buttonStyle(.plain)
            .disabled(pixel == nil)
            .accessibilityLabel(label(day: day, pixel: pixel))
        } else {
            Color.clear.frame(maxWidth: .infinity).frame(height: 17).accessibilityHidden(true)
        }
    }

    private func label(day: DayKey, pixel: YearPixel?) -> String {
        let date = day.utcDate.formatted(Date.FormatStyle(timeZone: .gmt).day().month(.wide))
        guard let pixel else { return String(localized: "\(date), nothing written") }
        let pages = String(localized: "\(pixel.entryIDs.count) pages")
        return [date, pages, pixel.mood?.title].compactMap { $0 }.joined(separator: ", ")
    }
}

/// What the colours mean.
struct PixelLegend: View {
    let byMood: Bool
    @Environment(DiaryStore.self) private var store

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Spacing.m) {
                if byMood {
                    ForEach(Mood.allCases) { mood in
                        HStack(spacing: Spacing.xxs) {
                            MoodGlyph(mood: mood, size: 14)
                            Text(mood.title).folioFont(.caption).foregroundStyle(.inkSecondary)
                        }
                    }
                } else {
                    ForEach(store.categories()) { category in
                        HStack(spacing: Spacing.xxs) {
                            RoundedRectangle(cornerRadius: 3).fill(category.color.color).frame(width: 12, height: 12)
                            Text(category.name).folioFont(.caption).foregroundStyle(.inkSecondary)
                        }
                    }
                }
                HStack(spacing: Spacing.xxs) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.ink.opacity(0.22)).frame(width: 12, height: 12)
                    Text(byMood ? "No mood" : "No category").folioFont(.caption).foregroundStyle(.inkSecondary)
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}
