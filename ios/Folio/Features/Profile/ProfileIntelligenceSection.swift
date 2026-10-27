import Speech
import SwiftUI

/// Dictation & Intelligence (SPEC §6.9, §8, §9): the dictation language, and plain
/// explanations when either feature isn't available on this iPhone.
struct ProfileIntelligenceSection: View {
    @AppStorage(PreferenceKeys.dictationLocale) private var dictationLocale = ""
    @State private var locales: [Locale] = []
    @State private var isSupported = true
    @State private var assistant = WritingAssistant()

    var body: some View {
        Section {
            Picker(selection: $dictationLocale) {
                Text("Same as iPhone").tag("")
                ForEach(locales, id: \.identifier) { locale in
                    Text(Self.name(of: locale)).tag(locale.identifier)
                }
            } label: {
                ProfileRowLabel(title: "Dictation language", systemImage: "mic")
            }
            Text(isSupported
                 ? "Dictation runs on your iPhone. Audio is never stored or sent anywhere."
                 : "Dictation isn't available in \(Self.name(of: DictationController.preferredLocale)) yet. You can use the mic on the keyboard instead.")
                .folioFont(.callout)
                .foregroundStyle(.inkSecondary)
            HStack(alignment: .top, spacing: Spacing.s) {
                Image(systemName: "sparkles").foregroundStyle(.ember).frame(width: 26).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Writing tools").folioFont(.body).foregroundStyle(.ink)
                    Text(Self.explanation(for: assistant.availability))
                        .folioFont(.callout)
                        .foregroundStyle(.inkSecondary)
                }
            }
            .padding(.vertical, Spacing.xxs)
            .accessibilityElement(children: .combine)
        } header: {
            Text("Dictation & Intelligence")
        }
        .listRowBackground(ProfileRowBackground())
        .task(id: dictationLocale) {
            if locales.isEmpty {
                locales = await DictationTranscriber.supportedLocales.sorted { Self.name(of: $0) < Self.name(of: $1) }
            }
            isSupported = await DictationTranscriber.supportedLocale(equivalentTo: DictationController.preferredLocale) != nil
        }
    }

    static func name(of locale: Locale) -> String {
        Locale.current.localizedString(forIdentifier: locale.identifier) ?? locale.identifier
    }

    static func explanation(for availability: WritingAssistant.Availability) -> LocalizedStringKey {
        switch availability {
        case .available:
            "Suggest a title, polish grammar and find tasks with ✦ in the composer. Apple's model runs on your iPhone; nothing is sent anywhere."
        case .unavailable(.deviceNotEligible):
            "This iPhone doesn't support Apple Intelligence, so ✦ is hidden. Everything else works the same."
        case .unavailable(.appleIntelligenceOff):
            "Turn on Apple Intelligence in Settings to use ✦ in the composer."
        case .unavailable(.modelNotReady):
            "Apple Intelligence is still getting ready on this iPhone. ✦ appears once it's done."
        case .unavailable(.language):
            "Apple's model doesn't support your iPhone's language yet, so ✦ is hidden."
        }
    }
}
