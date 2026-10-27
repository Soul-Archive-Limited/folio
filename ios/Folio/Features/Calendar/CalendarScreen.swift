import SwiftUI

/// The opening screen (SPEC §6.2): month grid over the aura, with the selected day's pages
/// and tasks underneath. Scrolling the panel up collapses the grid to the selected week,
/// tracking the finger 1:1.
struct CalendarScreen: View {
    @Bindable var model: CalendarModel

    @Environment(DiaryStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var width: Double = 402
    @State private var scrollPosition = ScrollPosition(edge: .top)
    @State private var viewportHeight: Double = 600
    @Namespace private var entryZoom

    var body: some View {
        NavigationStack(path: $model.path) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    AccessibleMonthList(model: model, onTitleTap: { model.showsJumpSheet = true })
                } else {
                    standardLayout
                }
            }
            .background { AuraBackground(month: model.visibleMonth.month) }
            .toolbarVisibility(.hidden, for: .navigationBar)
            .navigationDestination(for: UUID.self) { id in
                EntryDetailView(entryID: id)
                    .navigationTransition(.zoom(sourceID: id, in: entryZoom))
            }
        }
        .sheet(isPresented: $model.showsJumpSheet) {
            JumpSheet(model: model)
        }
    }

    private var standardLayout: some View {
        let layout = CalendarLayout(width: width)
        let firstWeekday = firstWeekday
        return VStack(spacing: Spacing.s) {
            CalendarHeader(model: model, onTitleTap: titleTapped)
            WeekdayRow(firstWeekday: firstWeekday, layout: layout)
                .padding(.horizontal, Spacing.sideMargin)
            ZStack(alignment: .top) {
                ScrollView {
                    DayPanel(model: model, zoomNamespace: entryZoom, onTitleTap: expand)
                        .padding(.horizontal, Spacing.sideMargin)
                        .padding(.top, Spacing.m)
                        .padding(.bottom, Spacing.m)
                        // Short days still need room to collapse the grid all the way: the
                        // furthest offset is contentHeight − viewport (viewport excludes the margin).
                        .frame(maxWidth: .infinity, minHeight: viewportHeight + layout.collapseDistance, alignment: .topLeading)
                }
                .contentMargins(.top, layout.fullGridHeight, for: .scrollContent)
                .contentMargins(.top, layout.fullGridHeight, for: .scrollIndicators)
                .scrollPosition($scrollPosition)
                .scrollTargetBehavior(CollapseSnapBehavior(distance: layout.collapseDistance, topInset: layout.fullGridHeight))
                .onScrollGeometryChange(for: Double.self) { geometry in
                    geometry.contentOffset.y + geometry.contentInsets.top
                } action: { _, offset in
                    model.collapseProgress = min(max(offset / layout.collapseDistance, 0), 1)
                }
                .onScrollGeometryChange(for: Double.self) { $0.containerSize.height } action: { _, height in
                    viewportHeight = height
                }
                // The panel stops above the "+" and the tab bar (tab bar + button + 16 pt), so
                // the last row scrolls fully clear and the "+" never covers a row.
                .scrollEdgeFade()
                .padding(.bottom, FloatingButtonMetrics.clearance)
                CalendarGridArea(model: model, layout: layout, firstWeekday: firstWeekday)
            }
        }
        .padding(.top, Spacing.xs)
        .onGeometryChange(for: Double.self) { $0.size.width } action: { width = $0 }
        #if DEBUG
        .task {
            guard DebugLaunchOptions.startsCollapsed else { return }
            try? await Task.sleep(for: .milliseconds(1800))
            withAnimation { scrollPosition.scrollTo(y: layout.collapseDistance) }
        }
        #endif
    }

    private var firstWeekday: Int {
        store.settings().firstWeekday ?? store.calendar.firstWeekday
    }

    private func titleTapped() {
        if model.collapseProgress > 0 { expand() } else { model.showsJumpSheet = true }
    }

    /// Scroll to top re-expands the grid (SPEC §6.2).
    private func expand() {
        withAnimation(FolioMotion.interactive(reduceMotion: reduceMotion)) {
            scrollPosition.scrollTo(edge: .top)
        }
    }
}

#Preview("Light") {
    let store = PreviewData.previewStore()
    CalendarScreen(model: CalendarModel(today: store.today))
        .environment(store)
}

#Preview("Dark") {
    let store = PreviewData.previewStore()
    CalendarScreen(model: CalendarModel(today: store.today))
        .environment(store)
        .preferredColorScheme(.dark)
}
