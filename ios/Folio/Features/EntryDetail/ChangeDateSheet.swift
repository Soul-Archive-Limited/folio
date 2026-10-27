import SwiftUI

/// Moves an entry to another day (back to 1900), keeping its time.
struct ChangeDateSheet: View {
    let entry: Entry

    @Environment(DiaryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var day: DayKey
    @State private var minutes: Int?

    init(entry: Entry) {
        self.entry = entry
        _day = State(initialValue: entry.day ?? DayKey(date: .now, calendar: .current))
        _minutes = State(initialValue: entry.minutesFromMidnight)
    }

    var body: some View {
        NavigationStack {
            ScrollView { ComposerDatePicker(day: $day, minutes: $minutes) }
                .navigationTitle("Change date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel", systemImage: "xmark") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Move", action: move).buttonStyle(.glassProminent).tint(.emberStrong)
                    }
                }
        }
        .presentationDetents([.large])
        .privacyCovered()
    }

    private func move() {
        store.move(entry, to: day, minutesFromMidnight: minutes)
        dismiss()
    }
}
