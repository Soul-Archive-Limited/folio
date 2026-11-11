import StoreKit
import SwiftUI

/// One Profile page (Batch N). Each is an inset-grouped list of the sections that used to sit
/// on one long Profile screen.
struct ProfilePageView: View {
    let page: ProfilePage

    var body: some View {
        Group {
            switch page {
            case .account: ProfileAccountPage()
            case .categories: CategoriesManagerView()
            case .appearance: ProfileList { ProfileAppearanceSection() }
            case .writing: ProfileList { ProfileWritingSection(); ProfileIntelligenceSection() }
            case .notifications: ProfileList { ProfileMemoriesSection(); ProfileTaskRemindersSection(); ProfileCalendarSection() }
            case .widgets: ProfileList { ProfileWidgetsSection() }
            case .privacy: ProfileList { ProfilePrivacySection() }
            case .data: ProfileDataPage()
            case .help: ProfileHelpPage()
            }
        }
        .navigationTitle(page.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The list style every Profile page shares.
struct ProfileList<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        List { content() }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .tint(.accentStrong)
            .background { AuraBackground() }
            .contentMargins(.bottom, Spacing.xxl, for: .scrollContent)
            .readableWidth()
    }
}

/// Account & Sync: sign-in for a guest; the account, sync, devices, the owner's invites,
/// recovery key, linking, sign out and delete for someone signed in.
struct ProfileAccountPage: View {
    @Environment(AccountModel.self) private var account
    @State private var routes = AccountRoutes()

    var body: some View {
        ProfileList {
            ProfileAccountSection(routes: routes)
        }
        .animation(FolioMotion.standard(), value: account.isSignedIn)
        .modifier(AccountPresentations(routes: routes))
    }
}

/// Your data: Recently Deleted (pushed), export, PDF and erase.
struct ProfileDataPage: View {
    @Environment(ProfileNavigation.self) private var navigation
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showsRecentlyDeleted = false

    var body: some View {
        ProfileList {
            ProfileDataSection(showsRecentlyDeleted: $showsRecentlyDeleted)
        }
        .onChange(of: showsRecentlyDeleted) { _, shows in
            guard shows else { return }
            showsRecentlyDeleted = false
            navigation.push(.recentlyDeleted, regular: sizeClass == .regular)
        }
    }
}

/// Task reminders (Batch N): where notifications stand, since reminders are set per task.
struct ProfileTaskRemindersSection: View {
    @State private var access: ReminderScheduler.Access?
    @Environment(\.openURL) private var openURL

    var body: some View {
        Section {
            ProfileRowLabel(title: "Task reminders", systemImage: "bell", detail: detail)
            if access == .denied {
                Button {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                } label: {
                    ProfileRowLabel(title: "Open Settings", systemImage: "gear", external: true)
                }
            }
        } header: {
            Text("Reminders")
        } footer: {
            Text("Turn on Remind me in a task to get a reminder. Reminders are set on each device, in its own time zone; nothing goes through a server.")
        }
        .listRowBackground(ProfileRowBackground())
        .task { access = await ReminderScheduler.shared.access() }
    }

    private var detail: String {
        switch access {
        case .granted: String(localized: "On")
        case .denied: String(localized: "Off in Settings")
        default: String(localized: "Asks when you first set one")
        }
    }
}

/// Help & About: the tour, the marks key, support, legal pages, company details and version.
struct ProfileHelpPage: View {
    @Environment(TourModel.self) private var tour: TourModel?
    @Environment(\.tabRouter) private var router
    @Environment(\.requestReview) private var requestReview
    @State private var showsMarkersKey = false

    var body: some View {
        ProfileList {
            Section("Help") {
                Button {
                    router?.open(.daysWrittenOn)
                    tour?.replay()
                } label: {
                    ProfileRowLabel(title: "Show the tour again", systemImage: "sparkles.rectangle.stack")
                }
                Button { showsMarkersKey = true } label: {
                    ProfileRowLabel(title: "What do the marks mean?", systemImage: "circle.grid.3x3")
                }
                Link(destination: Self.url("support")) {
                    ProfileRowLabel(title: "Support & FAQ", systemImage: "questionmark.circle", external: true)
                }
                Link(destination: URL(string: "mailto:support@devilsense.com")!) {
                    ProfileRowLabel(title: "Contact support", systemImage: "envelope", external: true)
                }
            }
            .listRowBackground(ProfileRowBackground())

            Section("Legal") {
                Link(destination: Self.url("privacy")) {
                    ProfileRowLabel(title: "Privacy Policy", systemImage: "hand.raised", external: true)
                }
                Link(destination: Self.url("terms")) {
                    ProfileRowLabel(title: "Terms of Use", systemImage: "doc.text", external: true)
                }
                Link(destination: Self.url("acceptable-use")) {
                    ProfileRowLabel(title: "Acceptable use", systemImage: "checkmark.shield", external: true)
                }
                Link(destination: Self.url("accessibility")) {
                    ProfileRowLabel(title: "Accessibility", systemImage: "accessibility", external: true)
                }
                Link(destination: Self.url("imprint")) {
                    ProfileRowLabel(title: "Company details", systemImage: "building.2", external: true)
                }
                Link(destination: Self.url("open-source")) {
                    ProfileRowLabel(title: "Open source licences", systemImage: "shippingbox", external: true)
                }
                Link(destination: URL(string: "https://github.com/Soul-Archive-Limited/folio")!) {
                    ProfileRowLabel(title: "Source code on GitHub", systemImage: "chevron.left.forwardslash.chevron.right", external: true)
                }
            }
            .listRowBackground(ProfileRowBackground())

            Section("About") {
                Link(destination: URL(string: "https://folio.devilsense.com")!) {
                    ProfileRowLabel(title: "Website", systemImage: "globe", external: true)
                }
                // The only place Folio asks for a rating (SPEC §6.9).
                Button { requestReview() } label: {
                    ProfileRowLabel(title: "Rate Folio", systemImage: "star")
                }
                ProfileRowLabel(title: "Version", systemImage: "info.circle", detail: Self.version)
            }
            .listRowBackground(ProfileRowBackground())

            Section {
                Text("Made by Soul Archive Ltd · registered in England and Wales, no. 16186654\n© 2026 Soul Archive Ltd")
                    .multilineTextAlignment(.center)
                    .folioFont(.caption)
                    .foregroundStyle(.inkSecondary)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }

            #if DEBUG
            ProfileDeveloperSection()
            #endif
        }
        .sheet(isPresented: $showsMarkersKey) { MarkersKeyView() }
    }

    static func url(_ path: String) -> URL {
        URL(string: "https://folio.devilsense.com/\(path)")!
    }

    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }
}
