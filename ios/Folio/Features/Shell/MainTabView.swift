import SwiftUI

/// The native iOS 26 tab bar (real Liquid Glass) with the four main tabs (SPEC §2).
struct MainTabView: View {
    @Environment(DiaryStore.self) private var store
    @State private var selection: AppTab = .calendar
    @State private var calendar: CalendarModel?
    @State private var requester = NewItemRequester()
    @State private var toasts = ToastCenter()
    @Namespace private var composerNamespace

    var body: some View {
        TabView(selection: $selection) {
            Tab("Calendar", systemImage: "calendar", value: .calendar) {
                if let calendar {
                    CalendarScreen(model: calendar)
                        .floatingAddButton(day: calendar.selectedDay, namespace: composerNamespace, onRequest: present)
                        .toastHost(toasts, bottomPadding: FloatingButtonMetrics.toastBottomPadding)
                }
            }
            Tab("Journal", systemImage: "book.pages", value: .journal) {
                JournalScreen()
                    .floatingAddButton(day: store.today, namespace: composerNamespace, onRequest: present)
                    .toastHost(toasts, bottomPadding: FloatingButtonMetrics.toastBottomPadding)
            }
            Tab("To-do", systemImage: "checklist", value: .todo) {
                TodoScreen()
                    .floatingAddButton(day: store.today, namespace: composerNamespace, onRequest: present)
                    .toastHost(toasts, bottomPadding: FloatingButtonMetrics.toastBottomPadding)
            }
            Tab("Profile", systemImage: "person.crop.circle", value: .profile) {
                ProfilePlaceholderView()
                    .toastHost(toasts, bottomPadding: Spacing.m)
            }
        }
        .tabBarMinimizeBehavior(selection.minimisesTabBar ? .onScrollDown : .never)
        .environment(\.newItemRequest, requester)
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

    private func present(_ request: NewItemRequest) {
        requester.send(request)
    }
}

#Preview("Light") {
    MainTabView()
        .environment(PreviewData.previewStore())
}

#Preview("Dark") {
    MainTabView()
        .environment(PreviewData.previewStore())
        .preferredColorScheme(.dark)
}
