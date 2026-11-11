import SwiftUI

/// The Profile tab (SPEC §6.9, redesigned in Batch N): a search field that finds any setting,
/// the profile card with Edit profile, one row of four stats, and grouped rows that each open
/// their own page — iPhone Settings style. It fits one iPhone 15 Pro screen at the default text
/// size. On iPad (regular width) the rows are a sidebar and the page shows beside them.
struct ProfileView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var model = ProfileNavigation()

    var body: some View {
        Group {
            if sizeClass == .regular {
                NavigationSplitView {
                    ProfileRoot(model: model)
                        .navigationSplitViewColumnWidth(min: 320, ideal: 360, max: 420)
                } detail: {
                    NavigationStack(path: $model.detailPath) {
                        ProfilePageView(page: model.selected ?? .account)
                            .navigationDestination(for: ProfileDestination.self) { $0.view }
                    }
                }
                .navigationSplitViewStyle(.balanced)
            } else {
                NavigationStack(path: $model.path) {
                    ProfileRoot(model: model)
                        .navigationDestination(for: ProfilePage.self) { ProfilePageView(page: $0) }
                        .navigationDestination(for: ProfileDestination.self) { $0.view }
                }
            }
        }
        .environment(model)
        .sheet(isPresented: $model.editsProfile) { EditProfileSheet() }
        #if DEBUG
        .onAppear { model.applyDebugOptions(regular: sizeClass == .regular) }
        #endif
    }
}

/// Which Profile page is open; shared by the root, the search results and the pages.
@Observable
final class ProfileNavigation {
    var path = NavigationPath()
    var selected: ProfilePage?
    var detailPath: [ProfileDestination] = []
    var editsProfile = false
    var query = ""

    /// Opens a page on iPhone (pushed) or iPad (selected in the sidebar).
    func open(_ page: ProfilePage, regular: Bool) {
        if regular {
            selected = page
            detailPath = []
        } else {
            path = NavigationPath([page])
        }
    }

    /// A setting found by search: its page, or the Edit profile sheet.
    func open(_ setting: ProfileSetting, regular: Bool) {
        if setting.pageRaw == "profile" { editsProfile = true } else { open(setting.page, regular: regular) }
    }

    /// Pages pushed past a page (Recently Deleted, Devices…).
    func push(_ destination: ProfileDestination, regular: Bool) {
        if regular { detailPath.append(destination) } else { path.append(destination) }
    }

    #if DEBUG
    /// `-FolioProfilePage account|appearance|…`, and the older `-FolioOpen categories|recentlyDeleted`.
    func applyDebugOptions(regular: Bool) {
        if let raw = DebugLaunchOptions.string("FolioProfilePage"), let page = ProfilePage(rawValue: raw) { open(page, regular: regular) }
        switch DebugLaunchOptions.string("FolioOpen") {
        case "categories", "categoryEdit": open(.categories, regular: regular)
        case "recentlyDeleted":
            open(.data, regular: regular)
            push(.recentlyDeleted, regular: regular)
        case "editProfile", "avatars", "avatarCrop": editsProfile = true
        default: break
        }
        if let query = DebugLaunchOptions.string("FolioProfileSearch") { self.query = query }
    }
    #endif
}

/// Screens pushed from inside a page.
enum ProfileDestination: Hashable {
    case recentlyDeleted

    @MainActor @ViewBuilder var view: some View {
        switch self {
        case .recentlyDeleted: RecentlyDeletedView()
        }
    }
}

/// The root: search, card, stats, rows.
struct ProfileRoot: View {
    @Bindable var model: ProfileNavigation

    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(AccountModel.self) private var account

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s) {
                CompactTitleText(title: "Profile")
                    .padding(.horizontal, Spacing.xxs)
                ProfileSearchField(text: $model.query)
                if model.query.trimmingCharacters(in: .whitespaces).isEmpty {
                    ProfileHeaderCard { model.editsProfile = true }
                    ProfileStatsRow()
                    ForEach(Array(ProfilePage.groups.enumerated()), id: \.offset) { _, group in
                        ProfileRowGroup(pages: group, selected: sizeClass == .regular ? model.selected : nil) {
                            model.open($0, regular: sizeClass == .regular)
                        }
                    }
                } else {
                    ProfileSearchResults(query: model.query, canInvite: account.session?.canInvite == true) {
                        model.open($0, regular: sizeClass == .regular)
                    }
                }
            }
            .padding(.horizontal, Spacing.m)
            .padding(.top, Spacing.xxs)
            .padding(.bottom, Spacing.xxl)
        }
        .scrollDismissesKeyboard(.immediately)
        .background { AuraBackground() }
        .navigationTitle("Profile")
        // The title is in the content; an empty bar would cost the 44 pt that lets the root fit
        // one iPhone 15 Pro screen (Batch N). Pages pushed from here show their own bar.
        .toolbarVisibility(sizeClass == .regular ? .automatic : .hidden, for: .navigationBar)
    }
}

/// A small search field at the top of Profile that finds any setting.
struct ProfileSearchField: View {
    @Binding var text: String
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(.folioSearch).foregroundStyle(.inkSecondary).accessibilityHidden(true)
            TextField("Search settings", text: $text)
                .focused($focused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .accessibilityIdentifier("profile.search")
            if !text.isEmpty {
                Button { text = ""; focused = false } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.inkTertiary)
                        .frame(width: 32, height: 32).contentShape(.rect)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .folioFont(.body)
        .padding(.leading, Spacing.s)
        .padding(.trailing, Spacing.xxs)
        .frame(minHeight: 40)
        .folioGlass(in: .capsule)
    }
}

/// One group of rows on the root, in a single glass panel with hairlines between rows.
struct ProfileRowGroup: View {
    let pages: [ProfilePage]
    var selected: ProfilePage?
    let onOpen: (ProfilePage) -> Void

    @Environment(DiaryStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(pages.enumerated()), id: \.element) { index, page in
                Button { onOpen(page) } label: {
                    HStack(spacing: Spacing.s) {
                        page.icon
                            .foregroundStyle(.accent)
                            .frame(width: 26)
                            .accessibilityHidden(true)
                        Text(page.title).foregroundStyle(.ink)
                        Spacer(minLength: Spacing.xs)
                        if let detail = detail(page) {
                            Text(detail).foregroundStyle(.inkSecondary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.inkTertiary)
                            .accessibilityHidden(true)
                    }
                    .folioFont(.body)
                    .padding(.horizontal, Spacing.s)
                    .frame(minHeight: Spacing.minHitTarget)
                    .background(selected == page ? Color.accent.opacity(0.2) : .clear)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected == page ? [.isSelected] : [])
                .accessibilityIdentifier("profile.page.\(page.rawValue)")
                .hoverEffect(.highlight)
                if index < pages.count - 1 {
                    Rectangle().fill(.hairline).frame(height: 1).padding(.leading, Spacing.s + 26 + Spacing.s)
                }
            }
        }
        .clipShape(.rect(cornerRadius: Radius.card))
        .folioGlass(in: .rect(cornerRadius: Radius.card), behindContent: true)
    }

    private func detail(_ page: ProfilePage) -> String? {
        switch page {
        case .categories: "\(store.categories().count)"
        case .data: store.trashCount > 0 ? String(localized: "\(store.trashCount) deleted") : nil
        default: nil
        }
    }
}

/// Settings matching the search, each opening its page.
struct ProfileSearchResults: View {
    let query: String
    let canInvite: Bool
    let onOpen: (ProfileSetting) -> Void

    var body: some View {
        let results = ProfileSetting.search(query, canInvite: canInvite)
        if results.isEmpty {
            Text("No settings match \u{201C}\(query.trimmingCharacters(in: .whitespaces))\u{201D}.")
                .folioFont(.callout)
                .foregroundStyle(.inkSecondary)
                .padding(.top, Spacing.l)
                .frame(maxWidth: .infinity)
        } else {
            VStack(spacing: 0) {
                ForEach(results) { setting in
                    Button { onOpen(setting) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(setting.title).folioFont(.body).foregroundStyle(.ink)
                                Text(setting.pageRaw == "profile" ? String(localized: "Edit profile") : setting.page.name)
                                    .folioFont(.caption).foregroundStyle(.inkSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.inkTertiary)
                                .accessibilityHidden(true)
                        }
                        .padding(.horizontal, Spacing.s)
                        .padding(.vertical, Spacing.xs)
                        .frame(minHeight: Spacing.minHitTarget)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    if setting != results.last {
                        Rectangle().fill(.hairline).frame(height: 1).padding(.leading, Spacing.s)
                    }
                }
            }
            .clipShape(.rect(cornerRadius: Radius.card))
            .folioGlass(in: .rect(cornerRadius: Radius.card), behindContent: true)
            .accessibilityIdentifier("profile.searchResults")
        }
    }
}

/// A row inside a page: icon, title and an optional value or an "opens elsewhere" arrow.
struct ProfileRowLabel: View {
    let title: LocalizedStringKey
    let icon: Image
    var detail: String?
    var external = false

    init(title: LocalizedStringKey, systemImage: String, detail: String? = nil, external: Bool = false) {
        self.init(title: title, icon: Image(systemName: systemImage), detail: detail, external: external)
    }

    /// A row with one of Folio's own symbols (Batch K), e.g. "folio.sync".
    init(title: LocalizedStringKey, image: String, detail: String? = nil, external: Bool = false) {
        self.init(title: title, icon: Image(image), detail: detail, external: external)
    }

    private init(title: LocalizedStringKey, icon: Image, detail: String?, external: Bool) {
        self.title = title
        self.icon = icon
        self.detail = detail
        self.external = external
    }

    var body: some View {
        HStack(spacing: Spacing.s) {
            icon
                .foregroundStyle(.accent)
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
