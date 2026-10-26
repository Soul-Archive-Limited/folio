import SwiftUI

/// Category filter (SPEC §6.2). Non-matching days fade their markers while active.
struct CalendarFilterMenu: View {
    @Bindable var model: CalendarModel
    @Environment(DiaryStore.self) private var store

    var body: some View {
        Menu {
            Button("All categories", systemImage: model.isFiltering ? "circle" : "checkmark.circle") {
                model.filter.removeAll()
            }
            Divider()
            ForEach(store.categories()) { category in
                Button {
                    model.toggleFilter(category.id)
                } label: {
                    Label(category.name, systemImage: model.filter.contains(category.id) ? "checkmark.circle.fill" : (category.symbol ?? "circle"))
                }
            }
        } label: {
            Label("Filter", systemImage: model.isFiltering ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease")
                .labelStyle(.iconOnly)
                .font(.body.weight(.semibold))
                .foregroundStyle(model.isFiltering ? AnyShapeStyle(.ember) : AnyShapeStyle(.ink))
                .frame(width: Spacing.minHitTarget, height: Spacing.minHitTarget)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .accessibilityLabel(model.isFiltering ? "Filter, on" : "Filter")
        .folioHaptic(.lightImpact, trigger: model.filter)
    }
}
