import SwiftUI
import WidgetKit

/// Quick add (Batch J): task, entry and dictate, one tap each.
struct QuickAddWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FolioQuickAdd", provider: SnapshotProvider()) { _ in
            QuickAddView()
                .containerBackground(for: .widget) { WidgetBackground() }
                .widgetURL(FolioRoute.newEntry.url)
        }
        .configurationDisplayName("Quick Add")
        .description("Start a task, a page or a dictation in one tap.")
        .supportedFamilies([.systemSmall])
    }
}

struct QuickAddView: View {
    var body: some View {
        VStack(spacing: 6) {
            button("New page", image: "folio.page.new", route: .newEntry, prominent: true)
            button("Add task", image: "folio.task.add", route: .newTask)
            button("Dictate", image: "folio.dictate", route: .dictate)
        }
    }

    private func button(_ title: LocalizedStringKey, image: String, route: FolioRoute, prominent: Bool = false) -> some View {
        Link(destination: route.url) {
            Label(title, image: image)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .foregroundStyle(prominent ? Color.white : WidgetPalette.ink)
                .background(prominent ? AnyShapeStyle(WidgetPalette.accentStrong) : AnyShapeStyle(WidgetPalette.ink.opacity(0.07)),
                            in: .capsule)
        }
    }
}
