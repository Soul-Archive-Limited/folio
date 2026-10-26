import SwiftUI

/// Stand-in for the composer (Phase 4) and task composer (Phase 5). It already uses the
/// real presentation: half sheet, calendar still visible and tappable above it.
struct ComposerPlaceholderSheet: View {
    let request: NewItemRequest
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.m) {
                Image(systemName: symbol)
                    .font(.largeTitle)
                    .foregroundStyle(.ember)
                    .accessibilityHidden(true)
                Text(title).folioFont(.title2)
                Text(dateText).folioFont(.callout).foregroundStyle(.inkSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        .presentationDragIndicator(.visible)
        .privacyCovered()
    }

    private var title: LocalizedStringKey {
        switch request {
        case .entry: "New entry"
        case .task: "New task"
        case .dictation: "Dictation"
        case .editEntry: "Edit entry"
        }
    }

    private var symbol: String {
        switch request {
        case .entry: "square.and.pencil"
        case .task: "checklist"
        case .dictation: "mic"
        case .editEntry: "square.and.pencil"
        }
    }

    private var dateText: String {
        let day: DayKey? = switch request {
        case .entry(let day), .dictation(let day): day
        case .task(let day): day
        case .editEntry: nil
        }
        guard let day else { return String(localized: "No date") }
        return day.utcDate.formatted(Date.FormatStyle(timeZone: .gmt).weekday(.wide).day().month(.wide))
    }
}

#Preview {
    Color.bg.sheet(isPresented: .constant(true)) {
        ComposerPlaceholderSheet(request: .entry(DayKey(date: .now, calendar: .current)))
    }
}
