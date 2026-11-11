import Testing
@testable import Folio

@MainActor
@Suite("Profile settings search (Batch N)")
struct ProfileSearchTests {
    @Test("Words match titles and keywords by prefix, case and accents ignored")
    func matches() {
        #expect(ProfileSetting.search("lock", canInvite: false).map(\.title).contains("Lock Folio"))
        #expect(ProfileSetting.search("DARK", canInvite: false).map(\.title) == ["Theme"])
        #expect(ProfileSetting.search("exp pdf", canInvite: false).map(\.title) == ["Export PDF"])
        #expect(ProfileSetting.search("   ", canInvite: false).isEmpty)
        #expect(ProfileSetting.search("zzz", canInvite: false).isEmpty)
    }

    @Test("Invite a friend is found only by someone who may invite")
    func ownerOnly() {
        #expect(ProfileSetting.search("invite", canInvite: false).isEmpty)
        #expect(ProfileSetting.search("invite", canInvite: true).map(\.title) == ["Invite a friend"])
    }

    @Test("Every setting points at a real page or the Edit profile sheet")
    func pages() {
        for setting in ProfileSetting.all {
            #expect(setting.pageRaw == "profile" || ProfilePage(rawValue: setting.pageRaw) != nil, "\(setting.title)")
        }
        #expect(ProfilePage.groups.flatMap(\.self).count == ProfilePage.allCases.count)
    }
}
