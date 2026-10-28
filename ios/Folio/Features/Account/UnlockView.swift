import SwiftUI

/// Step 7 (SPEC §6.1, §10.4): signed in to an existing account on a device without the key.
/// iCloud Keychain would have unlocked it already; otherwise scan from another device or
/// enter the recovery key.
struct UnlockView: View {
    let onCancel: () -> Void

    @State private var mode: Mode?

    enum Mode { case qr, recoveryKey }

    var body: some View {
        switch mode {
        case .qr:
            LinkQRView(onBack: { mode = nil })
        case .recoveryKey:
            RecoveryKeyEntryView(onBack: { mode = nil })
        case nil:
            AccountStepLayout(systemImage: "lock.open", title: "Unlock your diary",
                              subtitle: "Your diary is encrypted. This device needs its key from one of your other devices, or your recovery key.") {
                EmptyView()
            } actions: {
                Button { mode = .qr } label: {
                    Label("Scan from your other device", systemImage: "qrcode")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glassProminent)
                .tint(.emberStrong)
                Button { mode = .recoveryKey } label: {
                    Label("Enter recovery key", systemImage: "key")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glass)
                .foregroundStyle(.ink)
                Button("Not now", action: onCancel)
                    .foregroundStyle(.emberText)
                    .frame(minHeight: Spacing.minHitTarget)
            }
        }
    }
}
