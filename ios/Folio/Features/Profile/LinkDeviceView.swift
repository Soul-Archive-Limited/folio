import SwiftUI
import VisionKit

/// Profile → Link a browser or device (SPEC §10.4): scan the QR the other device shows, check
/// who is asking, confirm with Face ID, send the key.
struct LinkDeviceView: View {
    @Environment(AccountModel.self) private var account
    @Environment(\.dismiss) private var dismiss
    @State private var request: AccountAPI.LinkRequest?
    @State private var payload: LinkPayload?
    @State private var problem: LinkApprovalError?
    @State private var working = false
    @State private var done = false
    #if DEBUG
    @State private var pasted = ""
    #endif

    var body: some View {
        NavigationStack {
            Group {
                if let request, let payload {
                    LinkApprovalView(request: request, working: working, done: done,
                                     onAllow: { approve(payload, name: request.deviceName) }, onDeny: { dismiss() })
                } else {
                    scanner
                }
            }
            .background { AuraBackground() }
            .navigationTitle("Link a device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close", systemImage: "xmark") { dismiss() } }
            }
        }
    }

    private var scanner: some View {
        VStack(spacing: Spacing.l) {
            Text("On the new device or browser, choose “Scan from your other device”, then point this camera at the code.")
                .folioFont(.callout)
                .foregroundStyle(.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
            if DataScannerViewController.isSupported {
                QRScannerView { text in found(text) }
                    .clipShape(.rect(cornerRadius: Radius.card))
                    .frame(maxHeight: 360)
                    .padding(.horizontal, Spacing.xl)
            } else {
                Text("This device can't scan codes.").folioFont(.callout).foregroundStyle(.inkSecondary)
            }
            #if DEBUG
            HStack {
                TextField("Paste code text", text: $pasted)
                    .accessibilityIdentifier("linkPaste")
                Button("Use") { found(pasted) }.accessibilityIdentifier("linkPasteUse")
            }
            .padding(Spacing.m)
            .folioGlass(in: .capsule)
            .padding(.horizontal, Spacing.xl)
            #endif
            if let problem {
                Text(message(problem)).folioFont(.callout).foregroundStyle(.danger).multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding(.top, Spacing.l)
    }

    private func found(_ text: String) {
        guard payload == nil else { return }
        guard let parsed = LinkPayload(text: text) else {
            problem = .mismatch
            return
        }
        payload = parsed
        Task {
            do throws(LinkApprovalError) {
                request = try await account.linkRequest(for: parsed)
            } catch {
                problem = error
                payload = nil
            }
        }
    }

    private func approve(_ payload: LinkPayload, name: String) {
        working = true
        Task {
            defer { working = false }
            do throws(LinkApprovalError) {
                try await account.approveLink(payload, deviceName: name)
                done = true
                try? await Task.sleep(for: .seconds(1.5))
                dismiss()
            } catch .notAuthenticated {
            } catch {
                problem = error
                request = nil
                self.payload = nil
            }
        }
    }

    private func message(_ error: LinkApprovalError) -> LocalizedStringResource {
        switch error {
        case .expired: "That code expired. Ask the other device for a new one."
        case .mismatch: "That isn't a Folio link code, or it was changed on the way. Scan it again."
        case .network: "You're offline. Check your connection and try again."
        case .locked: "Unlock your diary on this device first."
        case .notAuthenticated: "Confirm it's you to continue."
        }
    }
}
