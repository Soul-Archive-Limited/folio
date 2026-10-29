import StoreKit
import SwiftUI

/// The Profile tab (SPEC §6.9). Rows for features that don't exist yet (Face ID lock, PDF
/// export) are left out rather than shown disabled.
struct ProfileView: View {
    @Environment(DiaryStore.self) private var store
    @Environment(TourModel.self) private var tour: TourModel?
    @Environment(AccountModel.self) private var account
    @Environment(\.tabRouter) private var router
    @Environment(\.requestReview) private var requestReview
    @State private var showsCategories = false
    @State private var showsRecentlyDeleted = false
    @State private var accountRoutes = AccountRoutes()
    #if DEBUG
    @State private var showsGallery = false
    #endif

    var body: some View {
        NavigationStack {
            List {
                // In a section header, not rows: an inset-grouped section draws its own
                // panel behind rows, which showed as a band behind the glass cards.
                Section {} header: {
                    VStack(spacing: Spacing.m) {
                        ProfileHeaderCard()
                        ProfileArchiveTiles()
                    }
                    .textCase(nil)
                    .padding(.horizontal, -Spacing.m)
                    .padding(.bottom, Spacing.s)
                }

                ProfileAccountSection(routes: accountRoutes)

                Section {
                    Button { showsCategories = true } label: {
                        ProfileRowLabel(title: "Categories", systemImage: "tag", detail: "\(store.categories().count)")
                    }
                }
                .listRowBackground(ProfileRowBackground())

                ProfileAppearanceSection()
                ProfileWritingSection()
                ProfileIntelligenceSection()
                ProfilePrivacySection()
                ProfileDataSection(showsRecentlyDeleted: $showsRecentlyDeleted)

                Section("Help") {
                    Button {
                        router?.open(.daysWrittenOn)
                        tour?.replay()
                    } label: {
                        ProfileRowLabel(title: "Show the tour again", systemImage: "sparkles.rectangle.stack")
                    }
                    Link(destination: Self.url("support")) {
                        ProfileRowLabel(title: "Support & FAQ", systemImage: "questionmark.circle", external: true)
                    }
                    Link(destination: URL(string: "mailto:support@devilsense.com")!) {
                        ProfileRowLabel(title: "Contact support", systemImage: "envelope", external: true)
                    }
                }
                .listRowBackground(ProfileRowBackground())

                Section("About") {
                    Link(destination: URL(string: "https://folio.devilsense.com")!) {
                        ProfileRowLabel(title: "Website", systemImage: "globe", external: true)
                    }
                    Link(destination: Self.url("privacy")) {
                        ProfileRowLabel(title: "Privacy Policy", systemImage: "hand.raised", external: true)
                    }
                    Link(destination: Self.url("terms")) {
                        ProfileRowLabel(title: "Terms", systemImage: "doc.text", external: true)
                    }
                    Link(destination: Self.url("open-source")) {
                        ProfileRowLabel(title: "Open source licences", systemImage: "shippingbox", external: true)
                    }
                    Link(destination: URL(string: "https://github.com/Soul-Archive-Limited/folio")!) {
                        ProfileRowLabel(title: "Source code on GitHub", systemImage: "chevron.left.forwardslash.chevron.right", external: true)
                    }
                    // The only place Folio asks for a rating (SPEC §6.9).
                    Button { requestReview() } label: {
                        ProfileRowLabel(title: "Rate Folio", systemImage: "star")
                    }
                    ProfileRowLabel(title: "Version", systemImage: "info.circle", detail: Self.version)
                }
                .listRowBackground(ProfileRowBackground())

                Section {
                    Text("Made by Soul Archive Ltd\n© 2026 Soul Archive Ltd")
                        .multilineTextAlignment(.center)
                        .folioFont(.caption)
                        .foregroundStyle(.inkSecondary)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }

                #if DEBUG
                ProfileDeveloperSection(showsGallery: $showsGallery)
                #endif
            }
            .listStyle(.insetGrouped)
            .animation(FolioMotion.standard(), value: account.isSignedIn)
            .scrollContentBackground(.hidden)
            .tint(.emberStrong)
            .background { AuraBackground() }
            .navigationTitle("Profile")
            .navigationDestination(isPresented: $showsCategories) { CategoriesManagerView() }
            .navigationDestination(isPresented: $showsRecentlyDeleted) { RecentlyDeletedView() }
            .modifier(AccountPresentations(routes: accountRoutes))
            // Leave the toast room above the tab bar.
            .contentMargins(.bottom, Spacing.xxl, for: .scrollContent)
        }
        #if DEBUG
        .onAppear {
            let open = DebugLaunchOptions.string("FolioOpen")
            if open == "categories" || open == "categoryEdit" { showsCategories = true }
            if open == "recentlyDeleted" { showsRecentlyDeleted = true }
        }
        .fullScreenCover(isPresented: $showsGallery) {
            DesignGalleryView()
                .overlay(alignment: .topTrailing) {
                    GlassIconButton(title: "Close", systemImage: "xmark") { showsGallery = false }
                        .padding(Spacing.m)
                }
                .privacyCovered()
        }
        #endif
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

/// A Profile row: icon, title and an optional value or an "opens elsewhere" arrow.
struct ProfileRowLabel: View {
    let title: LocalizedStringKey
    let systemImage: String
    var detail: String?
    var external = false

    var body: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: systemImage)
                .foregroundStyle(.ember)
                .frame(width: 26)
                .accessibilityHidden(true)
            Text(title).foregroundStyle(.ink)
            Spacer(minLength: Spacing.xs)
            if let detail {
                Text(detail).foregroundStyle(.inkSecondary)
            }
            if external {
                Image(systemName: "arrow.up.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.inkSecondary)
                    .accessibilityHidden(true)
            }
        }
        .folioFont(.body)
        .frame(minHeight: Spacing.minHitTarget)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(external ? .isLink : [])
    }
}

/// The soft elevated fill used by Profile rows, matching To-do rows.
struct ProfileRowBackground: View {
    var body: some View {
        Rectangle().fill(.bgElevated.opacity(0.55))
    }
}

#if DEBUG
#Preview {
    ProfileView()
        .environment(PreviewData.previewStore())
        .environment(ToastCenter())
}
#endif
