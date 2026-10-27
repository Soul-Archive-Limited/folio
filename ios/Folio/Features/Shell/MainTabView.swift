import SwiftUI

/// The native iOS 26 tab bar (real Liquid Glass) with the four main tabs (SPEC §2).
struct MainTabView: View {
    @Environment(DiaryStore.self) private var store
    @Environment(TourModel.self) private var tour: TourModel?
    @State private var selection: AppTab = .calendar
    @State private var calendar: CalendarModel?
    @State private var journal = JournalModel()
    @State private var requester = NewItemRequester()
    @State private var toasts = ToastCenter()
    @State private var router = TabRouter()
    @Namespace private var composerNamespace

    var body: some View {
        TabView(selection: $selection) {
            Tab("Calendar", systemImage: "calendar", value: .calendar) {
                if let calendar {
                    let isRoot = calendar.path.isEmpty
                    CalendarScreen(model: calendar)
                        .floatingAddButton(day: calendar.selectedDay, isVisible: isRoot, namespace: composerNamespace, onRequest: present)
                        .toastHost(toasts, trailingClearance: isRoot ? FloatingButtonMetrics.toastTrailingClearance : 0)
                }
            }
            Tab("Journal", systemImage: "book.pages", value: .journal) {
                let isRoot = journal.isAtRoot
                JournalScreen(model: journal)
                    .floatingAddButton(day: store.today, isVisible: isRoot, namespace: composerNamespace, onRequest: present)
                    .toastHost(toasts, trailingClearance: isRoot ? FloatingButtonMetrics.toastTrailingClearance : 0)
            }
            // No "+" on To-do: the full-width quick-add bar has its own expand button, and the
            // toast rides above that bar (owner review, Batch B).
            Tab("To-do", systemImage: "checklist", value: .todo) {
                TodoScreen()
            }
            Tab("Profile", systemImage: "person.crop.circle", value: .profile) {
                ProfileView()
                    .toastHost(toasts)
            }
        }
        .tabBarMinimizeBehavior(selection.minimisesTabBar ? .onScrollDown : .never)
        .tourHost(.main, tour)
        .onAppear(perform: connectTour)
        .onChange(of: requester.pending?.id) { old, new in
            if new != nil { tour?.didOpenComposer() } else if old != nil { tour?.didCloseComposer() }
        }
        .environment(\.newItemRequest, requester)
        .environment(\.tabRouter, router)
        .onChange(of: router.pending) { _, destination in
            if let destination { route(to: destination) }
        }
        .environment(toasts)
        .sheet(item: $requester.pending) { request in
            ComposerRoute(request: request, calendar: selection == .calendar ? calendar : nil, namespace: composerNamespace)
                .environment(toasts)
        }
        .task {
            guard calendar == nil else { return }
            let model = CalendarModel(today: store.today)
            #if DEBUG
            DebugLaunchOptions.apply(to: model, store: store)
            openDebugScreen(calendar: model)
            #endif
            calendar = model
        }
    }

    #if DEBUG
    private func openDebugScreen(calendar: CalendarModel) {
        if let tab = DebugLaunchOptions.tab { selection = tab }
        let firstEntry = store.entries(on: calendar.selectedDay).first { !$0.orderedPhotos.isEmpty }
            ?? store.entries(on: calendar.selectedDay).first
        switch DebugLaunchOptions.string("FolioOpen") {
        case "composer": requester.send(.entry(calendar.selectedDay))
        case "composerLarge": if let firstEntry { requester.send(.editEntry(firstEntry.id)) }
        case "taskComposer": requester.send(.task(calendar.selectedDay))
        case "entry": if let firstEntry { calendar.path = [firstEntry.id] }
        default: break
        }
    }
    #endif

    /// Archive tiles and the tour replay land on a tab's root, already filtered.
    private func route(to destination: TabRouter.Destination) {
        router.pending = nil
        switch destination {
        case .entries, .photos:
            journal.path = []
            journal.showsTrash = false
            journal.filter = []
            journal.mode = destination == .photos ? .photos : .timeline
            selection = .journal
        case .daysWrittenOn:
            calendar?.path = []
            selection = .calendar
        case .tasksDone:
            UserDefaults.standard.set(true, forKey: PreferenceKeys.todoCompletedExpanded)
            selection = .todo
        case .day(let day):
            calendar?.path = []
            calendar?.jump(to: day.monthKey, selecting: day)
            selection = .calendar
        case .todo:
            selection = .todo
        }
    }

    private func present(_ request: NewItemRequest) {
        requester.send(request)
    }

    /// Lets the tour move between tabs and open or close the composer (SPEC §6.15).
    private func connectTour() {
        tour?.navigator = TourNavigator(
            selectedTab: { selection },
            select: { tab in
                calendar?.path = []
                selection = tab
            },
            isComposerOpen: { requester.pending != nil },
            openComposer: {
                calendar?.path = []
                requester.send(.entry(calendar?.selectedDay ?? store.today))
            },
            closeComposer: { requester.pending = nil }
        )
    }
}

#if DEBUG
#Preview("Light") {
    MainTabView()
        .environment(PreviewData.previewStore())
}

#Preview("Dark") {
    MainTabView()
        .environment(PreviewData.previewStore())
        .preferredColorScheme(.dark)
}
#endif
