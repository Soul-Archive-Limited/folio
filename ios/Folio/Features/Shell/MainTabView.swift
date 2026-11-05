import SwiftUI

/// The native iOS 26 tab bar (real Liquid Glass) with the four main tabs (SPEC §2).
struct MainTabView: View {
    @Environment(DiaryStore.self) private var store
    @Environment(TourModel.self) private var tour: TourModel?
    @Environment(SyncEngine.self) private var sync
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection: AppTab = .calendar
    @State private var calendar: CalendarModel?
    @State private var journal = JournalModel()
    @State private var requester = NewItemRequester()
    @State private var toasts = ToastCenter()
    @State private var router = TabRouter()
    @Namespace private var composerNamespace
    /// A draft left from before a full close (cold launch); cleared once resumed or discarded.
    @State private var launchDraft: ComposerDraft?
    /// A `folio://` link that arrived before the calendar was ready (cold launch from a widget).
    @State private var pendingRoute: FolioRoute?

    var body: some View {
        TabView(selection: $selection) {
            Tab("Calendar", systemImage: "calendar", value: .calendar) {
                if let calendar {
                    let isRoot = calendar.path.isEmpty
                    CalendarScreen(model: calendar)
                        .overlay(alignment: .bottom) {
                            if let launchDraft, isRoot, requester.pending == nil {
                                DraftResumePill(draft: launchDraft,
                                                onResume: { requester.send(.resumeDraft); self.launchDraft = nil },
                                                onDiscard: discardLaunchDraft)
                                    .padding(.trailing, FloatingButtonMetrics.clearance)
                                    .padding(.horizontal, Spacing.sideMargin)
                                    .padding(.bottom, Spacing.m + 4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                        .animation(FolioMotion.standard(), value: launchDraft == nil)
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
        // iPad: the tabs become a sidebar (SPEC §6.16); iPhone keeps the tab bar.
        .tabViewStyle(.sidebarAdaptable)
        .tabBarMinimizeBehavior(selection.minimisesTabBar ? .onScrollDown : .never)
        .overlay { SheetBackdropDim(isVisible: requester.pending != nil) }
        .tourHost(.main, tour)
        .onAppear {
            connectTour()
            // Sync's own notices ("Signed out…") use the app's toasts.
            sync.toasts = toasts
        }
        .onChange(of: requester.pending?.id) { old, new in
            if new != nil { tour?.didOpenComposer() } else if old != nil { tour?.didCloseComposer() }
        }
        .environment(\.newItemRequest, requester)
        .environment(\.tabRouter, router)
        .onChange(of: router.pending) { _, destination in
            if let destination { route(to: destination) }
        }
        .environment(toasts)
        // Shared to Folio from other apps while it was away (Batch J).
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            Task {
                let added = await ShareInboxImporter.importPending(into: store)
                if added > 0 { toasts.show(ToastMessage(text: "Added \(added) shared to Folio", systemImage: "square.and.arrow.down")) }
            }
        }
        .onOpenURL { url in
            guard let route = FolioRoute(url: url) else { return }
            if calendar == nil { pendingRoute = route } else { open(route) }
        }
        .sheet(item: $requester.pending) { request in
            ComposerRoute(request: request, calendar: selection == .calendar ? calendar : nil, namespace: composerNamespace)
                .environment(toasts)
        }
        .task {
            guard calendar == nil else { return }
            if let draft = store.drafts.load(), !draft.isEmpty { launchDraft = draft }
            let model = CalendarModel(today: store.today)
            #if DEBUG
            DebugLaunchOptions.apply(to: model, store: store)
            openDebugScreen(calendar: model)
            #endif
            calendar = model
            if let pendingRoute {
                self.pendingRoute = nil
                open(pendingRoute)
            }
            #if DEBUG
            if PerfDriver.isEnabled {
                await PerfDriver.run(calendar: model, requester: requester) { selection = $0 }
            }
            #endif
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
        case "scan": requester.send(.scan)
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

    /// Widgets, controls and shortcuts (Batch J). Navigation only; Lock Folio covers it.
    private func open(_ link: FolioRoute) {
        let today = store.today
        switch link {
        case .newEntry: present(.entry(today))
        case .dictate: present(.dictation(today))
        case .newTask:
            selection = .todo
            present(.task(today))
        case .today, .onThisDay:
            requester.pending = nil
            // The day panel's On this day card sits at its top.
            route(to: .day(today))
        case .day(let raw):
            requester.pending = nil
            if let day = DayKey(rawValue: raw) { route(to: .day(day)) }
        case .task:
            requester.pending = nil
            selection = .todo
        case .search:
            requester.pending = nil
            calendar?.path = []
            selection = .calendar
            calendar?.showsSearch = true
        }
    }

    private func present(_ request: NewItemRequest) {
        // "+" offers the same draft itself; the pill isn't needed once a composer opens.
        launchDraft = nil
        requester.send(request)
    }

    private func discardLaunchDraft() {
        store.drafts.clear()
        launchDraft = nil
        toasts.show(ToastMessage(text: "Draft discarded", systemImage: "trash"))
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
