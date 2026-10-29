import SwiftUI

/// The first sync after signing in (SPEC §10.5): "Encrypting and syncing 412 pages…" with a
/// progress bar while a guest diary uploads, then done.
struct SyncProgressStep: View {
    let onDone: () -> Void

    @Environment(SyncEngine.self) private var sync
    @Environment(DiaryStore.self) private var store

    private var finished: Bool { sync.status != .syncing && sync.progress == nil }

    var body: some View {
        AccountStepLayout(systemImage: finished ? "checkmark.icloud" : "arrow.triangle.2.circlepath.icloud",
                          title: finished ? "You're all set" : "Syncing your diary",
                          subtitle: finished ? subtitleDone : "Everything is encrypted on this iPhone before it leaves.") {
            if let progress = sync.progress {
                VStack(spacing: Spacing.xs) {
                    ProgressView(value: Double(progress.done), total: Double(max(progress.total, 1)))
                        .tint(.emberStrong)
                    Text("Encrypting and syncing \(sync.migratingPages ?? progress.total) pages…")
                        .folioFont(.caption)
                        .foregroundStyle(.inkSecondary)
                        .monospacedDigit()
                }
            } else if !finished {
                ProgressView()
            }
        } actions: {
            Button(action: onDone) {
                Text(finished ? "Done" : "Continue in the background")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.glassProminent)
            .tint(.emberStrong)
        }
        .contentTransition(.opacity)
        .animation(.smooth, value: finished)
    }

    private var subtitleDone: LocalizedStringKey {
        switch sync.status {
        case .offline: "You're offline. Folio will sync when you're back."
        case .error: "Something went wrong while syncing. Folio will try again."
        default: "Your diary is encrypted and in sync. Open Folio on another device to see it there."
        }
    }
}
