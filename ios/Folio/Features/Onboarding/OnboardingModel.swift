import SwiftUI

/// The first-launch steps (SPEC §6.1, redesigned in Batch I — docs/ONBOARDING.md). They're
/// pushed on a `NavigationStack`, so going back is the system's interactive back swipe.
enum OnboardingStep: Int, CaseIterable, Hashable, Identifiable {
    case welcome, firstLine, uses, you, look, sync

    var id: Int { rawValue }
    var next: OnboardingStep? { OnboardingStep(rawValue: rawValue + 1) }
}

/// What you'll keep in Folio (step 3). Each makes a matching category, except Tasks.
enum OnboardingUse: String, CaseIterable, Identifiable {
    case memories, travel, tasks, oldDiaries, gratitude, work

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .memories: "Memories"
        case .travel: "Travel"
        case .tasks: "Tasks"
        case .oldDiaries: "Old diaries"
        case .gratitude: "Gratitude"
        case .work: "Work"
        }
    }

    var symbol: String {
        switch self {
        case .memories: "heart"
        case .travel: "airplane"
        case .tasks: "checklist"
        case .oldDiaries: "book.closed"
        case .gratitude: "sun.max"
        case .work: "briefcase"
        }
    }

    /// The category it creates: name, colour, symbol.
    var category: (name: String, color: CategoryColor, symbol: String)? {
        switch self {
        case .memories: (String(localized: "Memories"), .rose, "heart")
        case .travel: (String(localized: "Travel"), .ocean, "airplane")
        case .tasks: nil
        case .oldDiaries: (String(localized: "Old diaries"), .sand, "book.closed")
        case .gratitude: (String(localized: "Gratitude"), .sage, "sun.max")
        case .work: (String(localized: "Work"), .graphite, "briefcase")
        }
    }
}

/// The answers collected on the way; applied as you go (theme, season) or at the end.
@Observable
final class OnboardingModel {
    var path: [OnboardingStep] = []
    var name = ""
    var avatar: String?
    var uses: Set<OnboardingUse> = []
    /// Set once the first line or photo has landed on today.
    var firstEntryID: UUID?

    static let usesKey = "onboardingUses"

    var current: OnboardingStep { path.last ?? .welcome }

    func go(to step: OnboardingStep) {
        guard !path.contains(step) else { return }
        path.append(step)
    }

    /// Name, picture and categories (the theme and season were applied live).
    func apply(to store: DiaryStore) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty || avatar != nil {
            store.updateSettings { settings in
                if !clean.isEmpty { settings.displayName = String(clean.prefix(40)) }
                if let avatar { settings.avatar = avatar; settings.avatarPhoto = nil }
            }
        }
        let existing = Set(store.categories().map { $0.name.lowercased() })
        for use in OnboardingUse.allCases where uses.contains(use) {
            guard let category = use.category, !existing.contains(category.name.lowercased()) else { continue }
            _ = try? store.createCategory(name: category.name, color: category.color, symbol: category.symbol)
        }
        UserDefaults.standard.set(uses.map(\.rawValue).sorted(), forKey: Self.usesKey)
    }
}

/// The thin segmented bar in the top bar: where you are, and that the end is near.
struct OnboardingProgress: View {
    let step: OnboardingStep
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            ForEach(OnboardingStep.allCases.dropFirst()) { item in
                Capsule()
                    .fill(item.rawValue <= step.rawValue ? Color.ember : Color.inkTertiary.opacity(0.35))
                    .frame(width: 22, height: 4)
            }
        }
        .animation(reduceMotion ? FolioMotion.reduced : .smooth(duration: 0.3), value: step)
        .accessibilityElement()
        .accessibilityLabel("Step \(step.rawValue) of \(OnboardingStep.allCases.count - 1)")
    }
}

/// The same primary button on every step.
struct OnboardingPrimaryButton: View {
    let title: LocalizedStringKey
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.glassProminent)
        .tint(.emberStrong)
        .disabled(!isEnabled)
    }
}

/// A step's heading and one line under it.
struct OnboardingHeading: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Text(title)
                .folioFont(.title1)
                .foregroundStyle(.ink)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .folioFont(.callout)
                .foregroundStyle(.inkSecondary)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, Spacing.xl)
        // Taps on the words count as "outside", so they put the keyboard away.
        .contentShape(.rect)
        .onTapGesture { KeyboardDismissal.dismiss() }
    }
}
