import SwiftUI

/// The pages Profile opens, iPhone-Settings style (Batch N): the root is a profile card, one
/// row of stats and these rows; each opens its own page.
enum ProfilePage: String, CaseIterable, Hashable, Identifiable {
    case account, categories, appearance, writing, notifications, widgets, privacy, data, help

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .account: "Account & Sync"
        case .categories: "Categories"
        case .appearance: "Appearance"
        case .writing: "Writing & Dictation"
        case .notifications: "Reminders & Notifications"
        case .widgets: "Widgets"
        case .privacy: "Privacy & Security"
        case .data: "Your data"
        case .help: "Help & About"
        }
    }

    /// Plain text, for search results and accessibility.
    var name: String {
        switch self {
        case .account: String(localized: "Account & Sync")
        case .categories: String(localized: "Categories")
        case .appearance: String(localized: "Appearance")
        case .writing: String(localized: "Writing & Dictation")
        case .notifications: String(localized: "Reminders & Notifications")
        case .widgets: String(localized: "Widgets")
        case .privacy: String(localized: "Privacy & Security")
        case .data: String(localized: "Your data")
        case .help: String(localized: "Help & About")
        }
    }

    var icon: Image {
        switch self {
        case .account: Image(.folioSync)
        case .categories: Image(.folioCategory)
        case .appearance: Image(.folioAppearance)
        case .writing: Image(.folioDictate)
        case .notifications: Image(.folioMemories)
        case .widgets: Image(.folioWidgets)
        case .privacy: Image(.folioLock)
        case .data: Image(.folioExport)
        case .help: Image(systemName: "questionmark.circle")
        }
    }

    /// Root groups, in order.
    static let groups: [[ProfilePage]] = [
        [.account, .categories],
        [.appearance, .writing, .notifications, .widgets],
        [.privacy, .data, .help],
    ]
}

/// Every setting Profile has, so the search field at the top can find any of them (Batch N).
/// Words are matched by prefix, ignoring case and accents, against the title and keywords.
nonisolated struct ProfileSetting: Identifiable, Hashable, Sendable {
    let title: String
    let pageRaw: String
    let keywords: [String]
    /// Only for someone signed in who may invite (the owner).
    var ownerOnly = false

    var id: String { "\(pageRaw)|\(title)" }

    @MainActor var page: ProfilePage { ProfilePage(rawValue: pageRaw) ?? .help }

    static func make(_ title: String, _ page: String, _ keywords: String = "", ownerOnly: Bool = false) -> ProfileSetting {
        ProfileSetting(title: title, pageRaw: page, keywords: keywords.split(separator: " ").map(String.init), ownerOnly: ownerOnly)
    }

    static let all: [ProfileSetting] = [
        make(String(localized: "Name"), "profile", "edit profile your name greeting"),
        make(String(localized: "Profile picture"), "profile", "avatar photo picture folio avatars remove"),
        make(String(localized: "Sign in"), "account", "sync account apple google email web access"),
        make(String(localized: "Sync now"), "account", "sync status offline up to date"),
        make(String(localized: "Devices"), "account", "devices sessions browsers sign out other"),
        make(String(localized: "Invite a friend"), "account", "invite code friend", ownerOnly: true),
        make(String(localized: "Recovery key"), "account", "recovery key backup face id"),
        make(String(localized: "Link a browser or device"), "account", "link qr web browser new iphone"),
        make(String(localized: "Sign out"), "account", "sign out log out"),
        make(String(localized: "Delete account"), "account", "delete account remove close"),
        make(String(localized: "Categories"), "categories", "categories colours tags labels"),
        make(String(localized: "Theme"), "appearance", "theme dark light mode system appearance"),
        make(String(localized: "Writing font"), "appearance", "font serif sans new york typeface"),
        make(String(localized: "First day of week"), "appearance", "week monday sunday calendar start"),
        make(String(localized: "Season effect"), "appearance", "season effect leaves snow autumn spring winter summer monsoon"),
        make(String(localized: "Celebrations"), "appearance", "celebrations animation bloom sparkle motion"),
        make(String(localized: "Default category"), "writing", "default category new entries tasks"),
        make(String(localized: "Photo tiles on calendar"), "writing", "photo tiles calendar pictures"),
        make(String(localized: "Dictation language"), "writing", "dictation voice microphone language speech"),
        make(String(localized: "Writing tools"), "writing", "writing tools intelligence sparkle apple model"),
        make(String(localized: "On this day notification"), "notifications", "memories on this day notification morning"),
        make(String(localized: "Task reminders"), "notifications", "reminders remind notifications tasks alerts"),
        make(String(localized: "Apple Calendar events"), "notifications", "calendar events apple"),
        make(String(localized: "Show details on Home Screen"), "widgets", "widgets home screen details"),
        make(String(localized: "Show details on Lock Screen"), "widgets", "widgets lock screen details"),
        make(String(localized: "Lock Folio"), "privacy", "lock face id passcode touch id security"),
        make(String(localized: "Hide content in app switcher"), "privacy", "app switcher privacy cover hide"),
        make(String(localized: "Recently Deleted"), "data", "recently deleted trash bin restore"),
        make(String(localized: "Export as JSON + photos"), "data", "export json zip backup download"),
        make(String(localized: "Export PDF"), "data", "pdf print book export"),
        make(String(localized: "Erase data on this iPhone"), "data", "erase reset wipe remove all"),
        make(String(localized: "Show the tour again"), "help", "tour tips guide help"),
        make(String(localized: "What do the marks mean?"), "help", "marks key dots legend calendar"),
        make(String(localized: "Support & FAQ"), "help", "support faq help questions"),
        make(String(localized: "Contact support"), "help", "contact email support"),
        make(String(localized: "Privacy Policy"), "help", "privacy policy legal"),
        make(String(localized: "Terms of Use"), "help", "terms legal conditions"),
        make(String(localized: "Company details"), "help", "company imprint business address soul archive"),
        make(String(localized: "Version"), "help", "version build about"),
        make(String(localized: "Rate Folio"), "help", "rate review app store"),
    ]

    /// Settings whose title or keywords start with every typed word.
    static func search(_ query: String, canInvite: Bool, in settings: [ProfileSetting] = all) -> [ProfileSetting] {
        let terms = SearchText.words(in: query)
        guard !terms.isEmpty else { return [] }
        return settings.filter { setting in
            guard canInvite || !setting.ownerOnly else { return false }
            let words = Set(SearchText.words(in: ([setting.title] + setting.keywords).joined(separator: " ")))
            return terms.allSatisfy { term in words.contains { $0.hasPrefix(term) } }
        }
    }
}
