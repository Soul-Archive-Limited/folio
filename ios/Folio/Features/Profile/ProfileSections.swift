import SwiftUI

/// Account in guest mode (SPEC §6.9): "Sync & web access" with the sign-in buttons, or,
/// before sign-in exists in Release builds, a plain note that the diary is on this iPhone.
struct ProfileAccountSection: View {
    var body: some View {
        Section("Account") {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Label {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(FeatureFlags.showsSignIn ? "Sync & web access" : "On this iPhone only")
                            .folioFont(.headline)
                            .foregroundStyle(.ink)
                        Text(FeatureFlags.showsSignIn
                             ? "Use Folio on the web and on a new iPhone. Encrypted end to end."
                             : "Your diary is stored on this iPhone. Export it any time from Your data.")
                            .folioFont(.callout)
                            .foregroundStyle(.inkSecondary)
                    }
                } icon: {
                    Image(systemName: FeatureFlags.showsSignIn ? "arrow.triangle.2.circlepath.icloud" : "iphone")
                        .foregroundStyle(.ember)
                }
                if FeatureFlags.showsSignIn {
                    SyncSignInButtons()
                    LegalFooter()
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, Spacing.xs)
        }
        .listRowBackground(ProfileRowBackground())
    }
}

/// Theme, writing font and first day of the week (SPEC §6.9). These are synced settings.
struct ProfileAppearanceSection: View {
    @Environment(DiaryStore.self) private var store

    var body: some View {
        let settings = store.settings()
        Section("Appearance") {
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
        }
        .listRowBackground(ProfileRowBackground())
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

/// Privacy & Security: the app-switcher cover (SPEC §4.3). Face ID lock is hidden until built.
struct ProfilePrivacySection: View {
    @AppStorage(PreferenceKeys.privacyCoverEnabled) private var hidesInSwitcher = true

    var body: some View {
        Section {
            Toggle(isOn: $hidesInSwitcher) {
                ProfileRowLabel(title: "Hide content in app switcher", systemImage: "eye.slash")
            }
        } header: {
            Text("Privacy & Security")
        } footer: {
            Text("Covers your pages when you leave Folio, so they never show in the app switcher.")
        }
        .listRowBackground(ProfileRowBackground())
    }
}

/// Your data: export (JSON + photos zip, via the share sheet) and erase this iPhone.
struct ProfileDataSection: View {
    @Environment(DiaryStore.self) private var store
    @Environment(ToastCenter.self) private var toasts
    @State private var exporting = false
    @State private var shareItems: ShareItems?
    @State private var confirmsErase = false

    struct ShareItems: Identifiable {
        let id = UUID()
        let urls: [URL]
        let exporter: DataExporter
    }

    var body: some View {
        Section {
            Button(action: export) {
                HStack {
                    ProfileRowLabel(title: "Export as JSON + photos", systemImage: "square.and.arrow.up")
                    if exporting { ProgressView() }
                }
            }
            .disabled(exporting)
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
            Text("The export is made on your iPhone and isn't encrypted, so keep it somewhere safe.")
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
            Text("Every entry, photo, task and category on this iPhone is removed. This can't be undone.")
        }
        .folioHaptic(.warning, trigger: confirmsErase)
    }

    private func export() {
        exporting = true
        let exporter = DataExporter(store: store)
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
