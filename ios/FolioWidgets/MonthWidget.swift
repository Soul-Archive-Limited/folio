import SwiftUI
import UIKit
import WidgetKit

/// Month (Batch J): a mini calendar with dots, or photo tiles on the large size.
struct MonthWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FolioMonth", provider: SnapshotProvider()) { entry in
            MonthWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetBackground() }
                .widgetURL(FolioRoute.today.url)
        }
        .configurationDisplayName("Month")
        .description("Your month at a glance: days you wrote on, photos and tasks.")
        .supportedFamilies([.systemSmall, .systemLarge])
    }
}

struct MonthWidgetView: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let large = family == .systemLarge
        VStack(alignment: .leading, spacing: large ? 8 : 4) {
            Text(entry.date, format: .dateTime.month(.wide).year())
                .font(large ? .headline : .caption.weight(.bold))
                .foregroundStyle(WidgetPalette.ink)
            if let month = entry.month {
                Grid(horizontalSpacing: large ? 4 : 1, verticalSpacing: large ? 4 : 1) {
                    ForEach(0..<6, id: \.self) { row in
                        GridRow {
                            ForEach(0..<7, id: \.self) { column in
                                let raw = month.grid[row * 7 + column]
                                cell(raw, month: month, large: large)
                            }
                        }
                    }
                }
            } else {
                Spacer()
                Text("Open Folio once to fill this in.").font(.caption).foregroundStyle(WidgetPalette.ink.opacity(0.6))
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func cell(_ raw: String, month: WidgetSnapshot.Month, large: Bool) -> some View {
        let inMonth = raw.hasPrefix(String(format: "%04d-%02d", month.year, month.month))
        let day = month.days[raw]
        let isToday = raw == entry.dayKey
        let number = Int(raw.suffix(2)) ?? 0
        let photo = large && entry.homeDetails ? day?.photo.flatMap(image(named:)) : nil
        // The cell's size comes from the grid, never from the photo (a filled image would
        // push the grid wider than the widget).
        let content = ZStack(alignment: .topLeading) {
            Color.clear
                .overlay {
                    if let photo {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                            .overlay(Color.black.opacity(0.18))
                            .privacySensitive()
                    }
                }
                .clipped()
            VStack(spacing: 1) {
                Text("\(number)")
                    .font(.system(size: large ? 13 : 9, weight: isToday ? .bold : .medium))
                    .monospacedDigit()
                    .foregroundStyle(photo != nil ? .white : (isToday ? WidgetPalette.ember : WidgetPalette.ink.opacity(inMonth ? 1 : 0.3)))
                if photo == nil, let day, day.entries > 0 {
                    HStack(spacing: 1.5) {
                        ForEach(Array(day.dots.prefix(3).enumerated()), id: \.offset) { _, dot in
                            Circle().fill(WidgetPalette.pair(dot) ?? WidgetPalette.ink.opacity(0.5))
                                .frame(width: large ? 4 : 3, height: large ? 4 : 3)
                        }
                        if day.dots.isEmpty { Circle().fill(WidgetPalette.ember).frame(width: 3, height: 3) }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: photo == nil ? .center : .topLeading)
            .padding(photo == nil ? 0 : 3)
            if large, let day, day.openTasks + day.doneTasks > 0 {
                Image(systemName: day.openTasks == 0 ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(day.openTasks == 0 ? WidgetPalette.done : (photo != nil ? .white : WidgetPalette.ink.opacity(0.5)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(.rect(cornerRadius: large ? 8 : 4))
        .overlay {
            if isToday { RoundedRectangle(cornerRadius: large ? 8 : 4).strokeBorder(WidgetPalette.ember, lineWidth: 1.5) }
        }
        if large {
            Link(destination: FolioRoute.day(raw).url) { content }
        } else {
            content
        }
    }

    private func image(named name: String) -> UIImage? {
        guard let url = WidgetSnapshot.thumbsFolder?.appending(path: name) else { return nil }
        return UIImage(contentsOfFile: url.path(percentEncoded: false))
    }
}
