import SwiftUI

/// The native iOS 26 tab bar (real Liquid Glass) with the four main tabs (SPEC §2).
struct MainTabView: View {
    @Environment(DiaryStore.self) private var store
    @State private var selection: AppTab = .calendar
    @State private var calendar: CalendarModel?
    @State private var requester = NewItemRequester()

    var body: some View {
        TabView(selection: $selection) {
            Tab("Calendar", systemImage: "calendar", value: .calendar) {
                if let calendar {
                    CalendarScreen(model: calendar)
                        .floatingAddButton(day: calendar.selectedDay, onRequest: present)
                }
            }
            Tab("Journal", systemImage: "book.pages", value: .journal) {
                PlaceholderTabView(title: "Journal", systemImage: "book.pages",
                                   message: "Your journal is empty. Tap + to write your first page.")
                    .floatingAddButton(day: store.today, onRequest: present)
            }
            Tab("To-do", systemImage: "checklist", value: .todo) {
                PlaceholderTabView(title: "To-do", systemImage: "checkmark.seal", message: "All clear.")
                    .floatingAddButton(day: store.today, onRequest: present)
            }
            Tab("Profile", systemImage: "person.crop.circle", value: .profile) {
                ProfilePlaceholderView()
            }
        }
        .tabBarMinimizeBehavior(selection.minimisesTabBar ? .onScrollDown : .never)
        .environment(\.newItemRequest, requester)
        .sheet(item: $requester.pending) { request in
            ComposerPlaceholderSheet(request: request)
        }
        .task {
            guard calendar == nil else { return }
            let model = CalendarModel(today: store.today)
            #if DEBUG
            DebugLaunchOptions.apply(to: model, store: store)
            #endif
            calendar = model
        }
    }

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
