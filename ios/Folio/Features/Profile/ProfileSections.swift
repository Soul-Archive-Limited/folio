import SwiftUI

/// Theme, writing font and first day of the week (SPEC §6.9). These are synced settings.
struct ProfileAppearanceSection: View {
    @Environment(DiaryStore.self) private var store
    @AppStorage(SeasonEffectSetting.key) private var seasonEffect: SeasonEffectSetting = .auto
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let settings = store.settings()
        Section {
            Picker(selection: binding(settings.appearance) { $0.appearance = $1 }) {
                Text("System").tag(AppearancePreference.system.rawValue)
                Text("Light").tag(AppearancePreference.light.rawValue)
                Text("Dark").tag(AppearancePreference.dark.rawValue)
            } label: {
                ProfileRowLabel(title: "Theme", systemImage: "circle.lefthalf.filled")
            }
            Picker(selection: binding(settings.writingFont) { $0.writingFont = $1 }) {
                ForEach(WritingFont.allCases) { font in
                    Text(font.displayName).font(font.font()).tag(font.rawValue)
                }
            } label: {
                ProfileRowLabel(title: "Writing font", systemImage: "textformat")
            }
            Picker(selection: binding(settings.firstWeekday) { $0.firstWeekday = $1 }) {
                Text("Automatic").tag(Int?.none)
                Text("Monday").tag(Int?.some(2))
                Text("Sunday").tag(Int?.some(1))
                Text("Saturday").tag(Int?.some(7))
            } label: {
                ProfileRowLabel(title: "First day of week", systemImage: "calendar")
            }
            // Device-only; the aura's barely-there seasonal layer (Batch I).
            Picker(selection: $seasonEffect) {
                Text("Auto").tag(SeasonEffectSetting.auto)
                Text("Spring").tag(SeasonEffectSetting.spring)
                Text("Summer").tag(SeasonEffectSetting.summer)
                Text("Monsoon").tag(SeasonEffectSetting.monsoon)
                Text("Autumn").tag(SeasonEffectSetting.autumn)
                Text("Winter").tag(SeasonEffectSetting.winter)
                Text("Off").tag(SeasonEffectSetting.off)
            } label: {
                ProfileRowLabel(title: "Season effect", systemImage: "leaf")
            }
        } header: {
            Text("Appearance")
        } footer: {
            Text(seasonFooter)
        }
        .listRowBackground(ProfileRowBackground())
    }

    private var seasonFooter: String {
        if reduceMotion { return String(localized: "The season effect is off while Reduce Motion is on.") }
        if seasonEffect == .auto {
            let season = Season.current(month: Calendar.current.component(.month, from: AppClock.now))
            return String(localized: "Auto follows the month and your iPhone's region: \(season.displayName) now. It turns off in Low Power Mode.")
        }
        return String(localized: "It turns off in Low Power Mode and with Reduce Motion.")
    }

    private func binding<Value>(_ value: Value, set: @escaping (UserSettings, Value) -> Void) -> Binding<Value> {
        Binding(get: { value }, set: { newValue in store.updateSettings { set($0, newValue) } })
    }
}

/// Default category for new entries and tasks, and photo tiles on the calendar.
struct ProfileWritingSection: View {
    @Environment(DiaryStore.self) private var store
    @AppStorage(PreferenceKeys.showPhotoTiles) private var showsPhotoTiles = true

    var body: some View {
        let defaultID = store.settings().defaultCategoryID
        Section("Writing") {
            Picker(selection: Binding(get: { defaultID }, set: { id in store.updateSettings { $0.defaultCategoryID = id } })) {
                Text("None").tag(UUID?.none)
                ForEach(store.categories()) { category in
                    Text(category.name).tag(Optional(category.id))
                }
            } label: {
                ProfileRowLabel(title: "Default category", systemImage: "tag")
            }
            Toggle(isOn: $showsPhotoTiles) {
                ProfileRowLabel(title: "Photo tiles on calendar", systemImage: "photo")
            }
        }
        .listRowBackground(ProfileRowBackground())
    }
}

/// Privacy & Security: Lock Folio (Batch J) and the app-switcher cover (SPEC §4.3).
struct ProfilePrivacySection: View {
    @AppStorage(PreferenceKeys.privacyCoverEnabled) private var hidesInSwitcher = true
    @AppStorage(PreferenceKeys.lockEnabled) private var lockEnabled = false
    @AppStorage(PreferenceKeys.lockAfter) private var lockAfter = LockAfter.immediately.rawValue
    @State private var lock = AppLock.shared
    @State private var changingLock = false

    var body: some View {
        Section {
            Toggle(isOn: Binding(get: { lockEnabled }, set: { setLock($0) })) {
                ProfileRowLabel(title: "Lock Folio", systemImage: lock.methodSymbol, detail: lock.methodName)
            }
            .disabled(changingLock)
            .accessibilityIdentifier("profile.lock")
            if lockEnabled {
                Picker(selection: $lockAfter) {
                    ForEach(LockAfter.allCases) { Text($0.title).tag($0.rawValue) }
                } label: {
                    ProfileRowLabel(title: "Lock", systemImage: "timer")
                }
            }
            Toggle(isOn: $hidesInSwitcher) {
                ProfileRowLabel(title: "Hide content in app switcher", systemImage: "eye.slash")
            }
            .disabled(lockEnabled)
        } header: {
            Text("Privacy & Security")
        } footer: {
            Text(footer)
        }
        .listRowBackground(ProfileRowBackground())
    }

    private var footer: String {
        if let problem = lock.problem, !lockEnabled { return problem }
        return lockEnabled
            ? String(localized: "Folio asks for \(lock.methodName) when you come back, and always covers your pages in the app switcher.")
            : String(localized: "Covers your pages when you leave Folio, so they never show in the app switcher.")
    }

    private func setLock(_ on: Bool) {
        changingLock = true
        Task {
            if await lock.setEnabled(on) { lockEnabled = on }
            changingLock = false
        }
    }
}

/// Memories (Batch J): the opt-in morning "On this day" notification.
struct ProfileMemoriesSection: View {
    @AppStorage(OnThisDayNotifier.enabledKey) private var notifies = false
    @AppStorage(OnThisDayNotifier.minutesKey) private var minutes = 8 * 60
    @State private var showsExplainer = false
    @State private var showsDenied = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        Section {
            Toggle(isOn: Binding(get: { notifies }, set: { $0 ? turnOn() : (notifies = false) })) {
                ProfileRowLabel(title: "On this day notification", systemImage: "clock.arrow.circlepath")
            }
            .tint(.emberStrong)
            if notifies {
                DatePicker(selection: time, displayedComponents: .hourAndMinute) {
                    ProfileRowLabel(title: "Time", systemImage: "sun.horizon")
                }
            }
        } header: {
            Text("Memories")
        } footer: {
            Text("A note in the morning on days you wrote something in an earlier year. It names the year only, never your words.")
        }
        .listRowBackground(ProfileRowBackground())
        .onChange(of: notifies) { OnThisDayNotifier.shared.reschedule() }
        .onChange(of: minutes) { OnThisDayNotifier.shared.reschedule() }
        .sheet(isPresented: $showsExplainer) {
            PermissionExplainer(systemImage: "clock.arrow.circlepath",
                                message: "Folio can tell you in the morning when you wrote something on that date in an earlier year.",
                                footnote: "iOS will ask next.") {
                showsExplainer = false
                Task {
                    if await ReminderScheduler.shared.requestAccess() { notifies = true } else { showsDenied = true }
                }
            }
        }
        .alert("Notifications are off for Folio", isPresented: $showsDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
            }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("Turn on notifications for Folio in Settings whenever you'd like them.")
        }
    }

    private var time: Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: AppClock.now) ?? AppClock.now
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            minutes = (parts.hour ?? 8) * 60 + (parts.minute ?? 0)
        }
    }

    private func turnOn() {
        Task {
            switch await ReminderScheduler.shared.access() {
            case .granted: notifies = true
            case .denied: showsDenied = true
            default: showsExplainer = true
            }
        }
    }
}

/// Apple Calendar (Batch J): opt-in, read-only events beside the diary.
struct ProfileCalendarSection: View {
    @AppStorage(CalendarEvents.enabledKey) private var shows = false
    @Environment(CalendarEvents.self) private var events
    @State private var showsExplainer = false
    @State private var showsDenied = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        Section {
            Toggle(isOn: Binding(get: { shows && events.hasAccess }, set: { $0 ? turnOn() : (shows = false) })) {
                ProfileRowLabel(title: "Show Apple Calendar events", systemImage: "calendar.badge.clock")
            }
            .tint(.emberStrong)
        } header: {
            Text("Apple Calendar")
        } footer: {
            Text("Today's events in the day panel and a small mark on the calendar. Read on this iPhone only; never copied into Folio or synced.")
        }
        .listRowBackground(ProfileRowBackground())
        .onChange(of: shows) { events.invalidate() }
        .sheet(isPresented: $showsExplainer) {
            PermissionExplainer(systemImage: "calendar.badge.clock",
                                message: "Folio can show your calendar's events beside your diary. They stay on this iPhone.",
                                footnote: "iOS will ask next.") {
                showsExplainer = false
                Task { if await events.requestAccess() { shows = true } else { showsDenied = true } }
            }
        }
        .alert("Calendar access is off for Folio", isPresented: $showsDenied) {
            Button("Open Settings") { if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) } }
            Button("Not now", role: .cancel) {}
        }
    }

    private func turnOn() {
        switch events.access {
        case .granted: shows = true
        case .needsPrompt: showsExplainer = true
        case .denied: showsDenied = true
        }
    }
}

/// Widgets (Batch J): what the widgets may show. Stored in the App Group so they can read it.
struct ProfileWidgetsSection: View {
    @AppStorage(AppGroup.homeDetailsKey, store: AppGroup.defaults) private var homeDetails = true
    @AppStorage(AppGroup.lockDetailsKey, store: AppGroup.defaults) private var lockDetails = false

    var body: some View {
        Section {
            Toggle(isOn: $homeDetails) {
                ProfileRowLabel(title: "Show details on Home Screen", systemImage: "square.grid.2x2")
            }
            Toggle(isOn: $lockDetails) {
                ProfileRowLabel(title: "Show details on Lock Screen", systemImage: "lock.rectangle")
            }
        } header: {
            Text("Widgets")
        } footer: {
            Text("Details are task titles and photo tiles. Without them, widgets show counts only. Widgets read a small copy kept on this iPhone; it never syncs.")
        }
        .listRowBackground(ProfileRowBackground())
        .onChange(of: homeDetails) { WidgetSnapshotWriter.shared.writeNow() }
        .onChange(of: lockDetails) { WidgetSnapshotWriter.shared.writeNow() }
    }
}

/// Your data: Recently Deleted, export (JSON + photos zip, via the share sheet) and erase
/// this iPhone, which also empties Recently Deleted (SPEC §5.2).
struct ProfileDataSection: View {
    @Binding var showsRecentlyDeleted: Bool

    @Environment(DiaryStore.self) private var store
    @Environment(ToastCenter.self) private var toasts
    @State private var exporting = false
    @State private var exportIncludesTrash = false
    @State private var shareItems: ShareItems?
    @State private var confirmsErase = false
    @State private var showsPDF = false

    struct ShareItems: Identifiable {
        let id = UUID()
        let urls: [URL]
        let exporter: DataExporter
    }

    var body: some View {
        Section {
            Button { showsRecentlyDeleted = true } label: {
                ProfileRowLabel(title: "Recently Deleted", systemImage: "trash", detail: "\(store.trashCount)")
            }
            .accessibilityIdentifier("profile-recently-deleted")
            Button(action: export) {
                HStack {
                    ProfileRowLabel(title: "Export as JSON + photos", systemImage: "square.and.arrow.up")
                    if exporting { ProgressView() }
                }
            }
            .disabled(exporting)
            Button { showsPDF = true } label: {
                ProfileRowLabel(title: "Export PDF", systemImage: "doc.richtext")
            }
            .accessibilityIdentifier("profile.exportPDF")
            .sheet(isPresented: $showsPDF) { PDFExportSheet(today: store.today) }
            Toggle(isOn: $exportIncludesTrash) {
                ProfileRowLabel(title: "Include Recently Deleted in export", systemImage: "tray.full")
            }
            .tint(.emberStrong)
            Button(role: .destructive) { confirmsErase = true } label: {
                HStack(spacing: Spacing.s) {
                    Image(systemName: "trash").frame(width: 26).accessibilityHidden(true)
                    Text("Erase data on this iPhone")
                }
                .folioFont(.body)
                .foregroundStyle(.danger)
                .frame(minHeight: Spacing.minHitTarget)
            }
        } header: {
            Text("Your data")
        } footer: {
            Text("Deleted items stay in Recently Deleted for 30 days. The export is made on your iPhone and isn't encrypted, so keep it somewhere safe.")
        }
        .listRowBackground(ProfileRowBackground())
        .sheet(item: $shareItems, onDismiss: { shareItems?.exporter.cleanUp() }) { items in
            ShareSheet(items: items.urls) { items.exporter.cleanUp() }
                .presentationDetents([.medium, .large])
        }
        .confirmationDialog("Erase everything on this iPhone?", isPresented: $confirmsErase, titleVisibility: .visible) {
            Button("Erase data", role: .destructive) {
                store.eraseAll()
                toasts.show(ToastMessage(text: "Data erased", systemImage: "trash"))
            }
        } message: {
            Text("Every entry, photo, task and category on this iPhone is removed, including Recently Deleted. This can't be undone.")
        }
        .folioHaptic(.warning, trigger: confirmsErase)
    }

    private func export() {
        exporting = true
        let exporter = DataExporter(store: store, includesTrash: exportIncludesTrash)
        Task {
            defer { exporting = false }
            do {
                shareItems = ShareItems(urls: try await exporter.export(), exporter: exporter)
            } catch {
                exporter.cleanUp()
                toasts.show(ToastMessage(text: "Export didn't work. Try again.", systemImage: "exclamationmark.triangle"))
            }
        }
    }
}

/// The system share sheet for files.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [URL]
    let onComplete: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in onComplete() }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

#if DEBUG
/// DEBUG-only developer tools.
struct ProfileDeveloperSection: View {
    @Binding var showsGallery: Bool
    @Environment(DiaryStore.self) private var store
    @AppStorage(PreferenceKeys.hasOnboarded) private var hasOnboarded = true
    @AppStorage(PreferenceKeys.fakeIntelligenceUnavailable) private var fakesUnavailable = false

    var body: some View {
        Section("Developer") {
            Button("Design Gallery", systemImage: "swatchpalette") { showsGallery = true }
            Button("Load sample data", systemImage: "tray.and.arrow.down") { PreviewData.loadIfEmpty(into: store) }
                .disabled(!store.isEmpty)
            Button("Show onboarding again", systemImage: "arrow.counterclockwise") { hasOnboarded = false }
            Toggle("Fake “writing tools unavailable”", systemImage: "sparkles", isOn: $fakesUnavailable)
        }
        .listRowBackground(ProfileRowBackground())
    }
}
#endif
