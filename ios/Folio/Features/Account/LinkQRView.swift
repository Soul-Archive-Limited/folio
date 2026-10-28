import SwiftUI

/// "Scan from your other device" (SPEC §10.4): shows a QR for 5 minutes. On a signed-in
/// device: Profile → Link a browser or device → scan. The key arrives encrypted to this
/// device's one-time key, and this screen unlocks.
struct LinkQRView: View {
    let onBack: () -> Void

    @Environment(AccountModel.self) private var account
    @State private var model: LinkRequestModel?
    @State private var attempt = 0

    var body: some View {
        AccountStepLayout(systemImage: "qrcode.viewfinder", title: "Scan from your other device",
                          subtitle: "On a device that's already signed in, open Folio → Profile → Link a browser or device, and scan this code.") {
            content
        } actions: {
            if model?.phase == .expired || model?.phase == .failed {
                Button("Show a new code") { attempt += 1 }
                    .buttonStyle(.glassProminent)
                    .tint(.emberStrong)
            }
            Button("Back", action: onBack)
                .foregroundStyle(.emberText)
                .frame(minHeight: Spacing.minHitTarget)
        }
        .task(id: attempt) {
            let model = LinkRequestModel(account: account)
            self.model = model
            if let key = await model.run() { account.unlock(with: key) }
        }
    }

    @ViewBuilder private var content: some View {
        switch model?.phase {
        case .showing(let payload, let expiresAt):
            VStack(spacing: Spacing.s) {
                QRCodeImage(text: payload.text)
                    .frame(width: 240, height: 240)
                    .padding(Spacing.m)
                    .background(.white, in: .rect(cornerRadius: Radius.card))
                    .accessibilityLabel("Link code")
                Text(timerInterval: Date.now...expiresAt, countsDown: true)
                    .folioFont(.caption)
                    .foregroundStyle(.inkTertiary)
                    .monospacedDigit()
                #if DEBUG
                // Simulators have no camera: the approving device can paste this instead.
                Button("Copy code text") { UIPasteboard.general.string = payload.text }
                    .folioFont(.caption)
                    .accessibilityIdentifier("copyLinkText")
                #endif
            }
        case .expired:
            Text("This code expired.").folioFont(.callout).foregroundStyle(.inkSecondary)
        case .failed:
            Text("Couldn't create a code. Check your connection.").folioFont(.callout).foregroundStyle(.danger)
        case .starting, nil:
            ProgressView().frame(height: 272)
        }
    }
}
