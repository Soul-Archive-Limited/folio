import SwiftUI

/// "Up to date · Syncing… · Offline — will sync later · Error" with when it last synced
/// (SPEC §6.9). Tapping an error explains it.
struct SyncStatusRow: View {
    @Environment(SyncEngine.self) private var sync
    @State private var explainsError = false

    var body: some View {
        Button { if sync.status == .error { explainsError = true } } label: {
            HStack(spacing: Spacing.s) {
                Image(systemName: symbol)
                    .foregroundStyle(sync.status == .error ? .danger : .ember)
                    .frame(width: 26)
                    .symbolEffect(.rotate, isActive: sync.status == .syncing)
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(.ink)
                        .contentTransition(.opacity)
                    if let lastSynced = sync.lastSynced {
                        Text("Last synced \(lastSynced, format: .relative(presentation: .named))")
                            .folioFont(.caption)
                            .foregroundStyle(.inkSecondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .folioFont(.body)
            .animation(FolioMotion.standard(), value: sync.status)
            .frame(minHeight: Spacing.minHitTarget)
            .contentShape(.rect)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("syncStatus")
        .alert("Sync didn't finish", isPresented: $explainsError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Folio couldn't save some changes to your account. They're safe on this iPhone and Folio will try again. If this keeps happening, contact support.")
        }
    }

    private var title: LocalizedStringKey {
        switch sync.status {
        case .upToDate: "Up to date"
        case .syncing: "Syncing…"
        case .offline: "Offline — will sync later"
        case .error: "Sync error — tap for details"
        }
    }

    private var symbol: String {
        switch sync.status {
        case .upToDate: "checkmark.icloud"
        case .syncing: "arrow.triangle.2.circlepath"
        case .offline: "icloud.slash"
        case .error: "exclamationmark.icloud"
        }
    }
}
