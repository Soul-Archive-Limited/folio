import SwiftUI

/// Profile → Invite a friend (Batch J, owner only): make a one-time code (7 days), share it,
/// and revoke ones nobody has used. A code is shown once; the list shows its last two characters.
struct InvitesView: View {
    @Environment(AccountModel.self) private var account
    @State private var invites: [AccountAPI.Invite] = []
    @State private var fresh: AccountAPI.NewInvite?
    @State private var problem: String?
    @State private var busy = false

    var body: some View {
        List {
            Section {
                if let fresh {
                    VStack(spacing: Spacing.s) {
                        Text(fresh.code)
                            .font(.system(size: 34, weight: .bold, design: .monospaced))
                            .textSelection(.enabled)
                            .accessibilityLabel("Invite code \(fresh.code.map(String.init).joined(separator: " "))")
                        Text("Works once, until \(Date(timeIntervalSince1970: fresh.expiresAt / 1000).formatted(date: .abbreviated, time: .omitted)).")
                            .folioFont(.caption).foregroundStyle(.inkSecondary)
                        ShareLink(item: message(fresh)) {
                            Label("Share invite", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity, minHeight: Spacing.minHitTarget)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.emberStrong)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.s)
                }
                Button { Task { await make() } } label: {
                    ProfileRowLabel(title: fresh == nil ? "Make an invite" : "Make another", systemImage: "plus.circle")
                }
                .disabled(busy)
                .accessibilityIdentifier("invites.make")
            } footer: {
                Text("Folio is invite-only for now. Each code makes one new account and lasts 7 days. People who already have an account don't need one.")
            }
            if !invites.isEmpty {
                Section("Your invites") {
                    ForEach(invites) { invite in
                        HStack {
                            Text("····-··\(invite.hint)").font(.body.monospaced())
                            Spacer()
                            Text(statusText(invite)).folioFont(.caption).foregroundStyle(invite.status == "open" ? .emberText : .inkSecondary)
                        }
                        .swipeActions {
                            if invite.status == "open" {
                                Button("Revoke", role: .destructive) { Task { await revoke(invite) } }
                            }
                        }
                        .contextMenu {
                            if invite.status == "open" {
                                Button("Revoke", systemImage: "xmark.circle", role: .destructive) { Task { await revoke(invite) } }
                            }
                        }
                    }
                }
            }
            if let problem { Text(problem).foregroundStyle(.danger) }
        }
        .navigationTitle("Invite a friend")
        .task { await load() }
        .refreshable { await load() }
    }

    private func message(_ invite: AccountAPI.NewInvite) -> String {
        String(localized: "Join me on Folio, a private diary. Your invite code: \(invite.code) (works once, for 7 days). Get Folio: https://folio.devilsense.com/download")
    }

    private func statusText(_ invite: AccountAPI.Invite) -> String {
        switch invite.status {
        case "open": String(localized: "Until \(Date(timeIntervalSince1970: invite.expiresAt / 1000).formatted(date: .abbreviated, time: .omitted))")
        case "used": String(localized: "Used")
        case "revoked": String(localized: "Revoked")
        default: String(localized: "Expired")
        }
    }

    private func load() async {
        do throws(APIError) {
            invites = try await account.invites()
        } catch {
            problem = error.signInProblem == .offline ? String(localized: "You're offline.") : String(localized: "Couldn't load your invites.")
        }
    }

    private func make() async {
        busy = true
        defer { busy = false }
        do throws(APIError) {
            fresh = try await account.makeInvite()
            problem = nil
            await load()
        } catch .server(409, _) {
            problem = String(localized: "You have 20 open invites. Revoke one or wait for them to be used.")
        } catch {
            problem = String(localized: "Couldn't make an invite. Try again.")
        }
    }

    private func revoke(_ invite: AccountAPI.Invite) async {
        try? await account.revokeInvite(invite.id)
        await load()
    }
}
