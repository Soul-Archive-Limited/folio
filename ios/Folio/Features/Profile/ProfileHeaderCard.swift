import SwiftUI

/// The profile card (Batch N): picture, name, "Writing since March 2019" and Edit profile.
/// No streaks anywhere.
struct ProfileHeaderCard: View {
    let onEdit: () -> Void

    @Environment(DiaryStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let name = store.settings().displayName
        let stats = store.profileStatsValue
        // Batch O: at accessibility sizes "Edit profile" beside the name split into letters;
        // it moves below the name there.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.s))
            : AnyLayout(HStackLayout(spacing: Spacing.s))
        layout {
            Button(action: onEdit) { ProfileAvatar(size: 56) }
                .buttonStyle(.pressable)
                .accessibilityLabel("Profile picture")
                .accessibilityHint("Edits your profile")
            VStack(alignment: .leading, spacing: 2) {
                Text(name.isEmpty ? String(localized: "Add your name") : name)
                    .folioFont(.headline)
                    .foregroundStyle(name.isEmpty ? .inkSecondary : .ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(summary(stats))
                    .folioFont(.callout)
                    .foregroundStyle(.inkSecondary)
                    .lineLimit(2)
            }
            .accessibilityElement(children: .combine)
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: Spacing.xs) }
            Button("Edit profile", action: onEdit)
                .folioFont(.callout)
                .fontWeight(.semibold)
                .buttonStyle(.glass)
                .accessibilityIdentifier("profile.edit")
        }
        .padding(Spacing.s)
        .folioGlass(in: .rect(cornerRadius: Radius.card))
        .task(id: store.revision) { await store.refreshProfileStats() }
    }

    private func summary(_ stats: ProfileStats) -> String {
        guard let since = stats.writingSince, stats.entries > 0 else { return String(localized: "Your first page is waiting.") }
        let month = since.startDate(in: store.calendar).formatted(.dateTime.month(.wide).year())
        return String(localized: "Writing since \(month)")
    }
}

/// One compact row of four stats (Batch N): Pages · Days written on · Photos · Tasks done.
/// Each opens its tab, filtered. Counts, never streaks.
struct ProfileStatsRow: View {
    @Environment(DiaryStore.self) private var store
    @Environment(\.tabRouter) private var router

    var body: some View {
        let stats = store.profileStatsValue
        HStack(spacing: 0) {
            stat("Pages", value: stats.entries, to: .entries)
            divider
            stat("Days written on", value: stats.daysWrittenOn, to: .daysWrittenOn)
            divider
            stat("Photos", value: stats.photos, to: .photos)
            divider
            stat("Tasks done", value: stats.tasksDone, to: .tasksDone)
        }
        .padding(.vertical, Spacing.xs)
        .folioGlass(in: .rect(cornerRadius: Radius.card))
    }

    private var divider: some View {
        Rectangle().fill(.hairline).frame(width: 1, height: 32).accessibilityHidden(true)
    }

    private func stat(_ title: LocalizedStringKey, value: Int, to destination: TabRouter.Destination) -> some View {
        Button { router?.open(destination) } label: {
            VStack(spacing: 1) {
                Text(value, format: .number)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.ink)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(title)
                    .folioFont(.micro)
                    .foregroundStyle(.inkSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, minHeight: Spacing.minHitTarget)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens it")
    }
}

/// Initials in an accent circle, or a person glyph when there's no name.
struct Monogram: View {
    let name: String
    var size: Double = 64

    var body: some View {
        ZStack {
            Circle().fill(.accent.gradient)
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
