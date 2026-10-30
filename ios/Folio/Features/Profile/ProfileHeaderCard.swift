import SwiftUI

/// Monogram, name (tap to edit) and "Writing since March 2019 · 412 pages" (SPEC §6.9).
/// No streaks anywhere.
struct ProfileHeaderCard: View {
    @Environment(DiaryStore.self) private var store
    @State private var editsName = false
    @State private var draftName = ""

    var body: some View {
        let name = store.settings().displayName
        let stats = store.profileStatsValue
        GlassCard {
            HStack(spacing: Spacing.m) {
                AvatarMenu { ProfileAvatar(size: 64) }
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Button {
                        draftName = name
                        editsName = true
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            Text(name.isEmpty ? String(localized: "Add your name") : name)
                                .folioFont(.title2)
                                .foregroundStyle(name.isEmpty ? .inkSecondary : .ink)
                            Image(systemName: "pencil")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.inkSecondary)
                                .accessibilityHidden(true)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Edits your name")
                    Text(summary(stats))
                        .folioFont(.callout)
                        .foregroundStyle(.inkSecondary)
                }
                Spacer(minLength: 0)
            }
        }
        .alert("Your name", isPresented: $editsName) {
            TextField("Name", text: $draftName)
                .textContentType(.givenName)
            Button("Save") {
                let clean = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
                store.updateSettings { $0.displayName = String(clean.prefix(40)) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Used to greet you.")
        }
        .task(id: store.revision) { await store.refreshProfileStats() }
    }

    private func summary(_ stats: ProfileStats) -> String {
        guard let since = stats.writingSince, stats.entries > 0 else { return String(localized: "Your first page is waiting.") }
        let month = since.startDate(in: store.calendar).formatted(.dateTime.month(.wide).year())
        let pages = stats.entries == 1 ? String(localized: "1 page") : String(localized: "\(stats.entries) pages")
        return String(localized: "Writing since \(month) · \(pages)")
    }
}

/// Initials in an ember circle, or a person glyph when there's no name.
struct Monogram: View {
    let name: String
    var size: Double = 64

    var body: some View {
        ZStack {
            Circle().fill(.ember.gradient)
            if initials.isEmpty {
                Image(systemName: "person.fill").foregroundStyle(.white)
            } else {
                Text(initials).fontWeight(.semibold).foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .font(.system(size: size * 0.34))
        .accessibilityHidden(true)
    }

    var initialsForTesting: String { initials }

    private var initials: String {
        name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }
}
