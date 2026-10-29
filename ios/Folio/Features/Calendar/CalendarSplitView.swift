import SwiftUI

/// iPad and other regular-width windows (SPEC §6.16): a resizable split with the month on
/// the left and the selected day's pages, tasks and entry detail on the right. The tab
/// sidebar comes from the `TabView`'s sidebar-adaptable style.
struct CalendarSplitView: View {
    @Bindable var model: CalendarModel

    @Environment(DiaryStore.self) private var store
    @State private var columns = NavigationSplitViewVisibility.all
    @State private var size = CGSize(width: 460, height: 800)
    @Namespace private var entryZoom

    var body: some View {
        NavigationSplitView(columnVisibility: $columns) {
            monthColumn
                .navigationSplitViewColumnWidth(min: 360, ideal: 480, max: 760)
                .toolbarVisibility(.hidden, for: .navigationBar)
        } detail: {
            NavigationStack(path: $model.path) {
                ScrollView {
                    DayPanel(model: model, zoomNamespace: entryZoom, onTitleTap: {})
                        .padding(.horizontal, Spacing.sideMargin)
                        .padding(.vertical, Spacing.m)
                        .frame(maxWidth: 720, alignment: .topLeading)
                        .frame(maxWidth: .infinity)
                }
                .contentMargins(.bottom, FloatingButtonMetrics.clearance, for: .scrollContent)
                .background { AuraBackground(month: model.visibleMonth.month) }
                .toolbarVisibility(.hidden, for: .navigationBar)
                .navigationDestination(for: UUID.self) { id in
                    EntryDetailView(entryID: id)
                        .navigationTransition(.zoom(sourceID: id, in: entryZoom))
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: columns) { _, visibility in
            // The month column is the point of this screen: keep it on screen.
            if visibility != .all { columns = .all }
        }
        .onAppear { model.collapseProgress = 0 }
        .sheet(isPresented: $model.showsJumpSheet) {
            JumpSheet(model: model)
        }
    }

    private var monthColumn: some View {
        let layout = CalendarLayout.fitting(size, reserved: Self.chromeHeight)
        let firstWeekday = store.settings().firstWeekday ?? store.calendar.firstWeekday
        return VStack(spacing: Spacing.s) {
            CalendarHeader(model: model, onTitleTap: { model.showsJumpSheet = true })
            WeekdayRow(firstWeekday: firstWeekday, layout: layout)
                .padding(.horizontal, Spacing.sideMargin)
            CalendarGridArea(model: model, layout: layout, firstWeekday: firstWeekday)
            Spacer(minLength: 0)
        }
        .frame(width: layout.width)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, Spacing.xs)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .background { AuraBackground(month: model.visibleMonth.month).ignoresSafeArea() }
    }

    /// Header, weekday row and spacing above the grid.
    private static let chromeHeight: Double = 120
}

extension CalendarLayout {
    /// The largest square-celled grid that fits both the column's width and its height.
    static func fitting(_ size: CGSize, reserved: Double) -> CalendarLayout {
        let byWidth = CalendarLayout(width: size.width)
        let availableHeight = max(size.height - reserved, 0)
        guard byWidth.fullGridHeight > availableHeight else { return byWidth }
        let cell = (availableHeight - gap * 5 - panelPadding * 2) / 6
        let width = cell * 7 + gap * 6 + panelPadding * 2 + Spacing.sideMargin * 2
        return CalendarLayout(width: max(width, 320))
    }
}
