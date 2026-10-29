import FolioCrypto
import SwiftUI

/// The recovery key (SPEC §6.13): large monospaced groups on a glass card, Copy · Save to Files
/// · Print, the warning, and — while setting up — typing the last four characters to continue.
struct RecoveryKeyView: View {
    let key: RecoveryKey
    /// Setting up: Continue needs the last four characters. Otherwise it's Profile's "Show".
    var confirming = true
    var onContinue: () async -> Void = {}

    @State private var typed = ""
    @State private var continuing = false
    @State private var exporting = false
    @State private var copied = 0

    private var confirmed: Bool { typed.uppercased().filter { !$0.isWhitespace } == key.confirmationSuffix }

    var body: some View {
        AccountStepLayout(systemImage: "key", title: "Your recovery key",
                          subtitle: "This key is the only way to read your diary on a new device if your iPhone is lost. We can't recover it for you.") {
            VStack(spacing: Spacing.m) {
                GlassCard(padding: Spacing.l) {
                    Text(key.displayString)
                        .font(.system(size: 24, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.ink)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(Text(key.displayString.map { String($0) }.joined(separator: " ")))
                        .accessibilityIdentifier("recoveryKey")
                }
                HStack(spacing: Spacing.xs) {
                    Button("Copy", systemImage: "doc.on.doc") {
                        RecoveryKeyExport.copy(key)
                        copied += 1
                    }
                    Button("Save", systemImage: "folder") { exporting = true }
                    Button("Print", systemImage: "printer") { RecoveryKeyExport.print(key) }
                }
                .buttonStyle(.glass)
                .labelStyle(.titleAndIcon)
                .folioFont(.callout)
                if confirming { confirmField }
            }
        } actions: {
            if confirming {
                Button {
                    continuing = true
                    Task {
                        await onContinue()
                        continuing = false
                    }
                } label: {
                    Group {
                        if continuing { ProgressView() } else { Text("Continue") }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glassProminent)
                .tint(.emberStrong)
                .disabled(!confirmed || continuing)
            }
        }
        .fileExporter(isPresented: $exporting, document: RecoveryKeyDocument(key: key), contentType: .plainText,
                      defaultFilename: "Folio Recovery Key") { _ in }
        .folioHaptic(.success, trigger: copied)
    }

    private var confirmField: some View {
        VStack(spacing: Spacing.xs) {
            Text("To make sure you saved it, type the last 4 characters.")
                .folioFont(.callout)
                .foregroundStyle(.inkSecondary)
                .multilineTextAlignment(.center)
            TextField("Last 4", text: $typed)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .multilineTextAlignment(.center)
                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                .frame(width: 160, height: 50)
                .folioGlass(in: .capsule)
                .accessibilityLabel("Last four characters of the recovery key")
                .accessibilityIdentifier("recoveryConfirm")
                .onChange(of: typed) { _, new in if new.count > 6 { typed = String(new.prefix(6)) } }
            if typed.count >= 4 && !confirmed {
                Text("That doesn't match the end of your key.")
                    .folioFont(.caption)
                    .foregroundStyle(.danger)
            }
        }
    }
}

#if DEBUG
#Preview {
    RecoveryKeyView(key: .generate())
        .background { AuraBackground() }
}
#endif
