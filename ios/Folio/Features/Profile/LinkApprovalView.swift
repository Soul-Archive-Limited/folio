import SwiftUI

/// "Allow Chrome on Mac to read your diary?" (SPEC §10.4), then Face ID.
struct LinkApprovalView: View {
    let request: AccountAPI.LinkRequest
    let working: Bool
    let done: Bool
    let onAllow: () -> Void
    let onDeny: () -> Void

    var body: some View {
        AccountStepLayout(systemImage: done ? "checkmark.circle" : (request.platform == "web" ? "globe" : "iphone"),
                          title: done ? "Linked" : "Allow \(request.deviceName) to read your diary?",
                          subtitle: done ? "It can now read and sync your diary."
                                         : "Only allow a device or browser you're using right now. It will be able to read every entry.") {
            EmptyView()
        } actions: {
            if !done {
                Button(action: onAllow) {
                    Group {
                        if working { ProgressView() } else { Text("Allow") }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glassProminent)
                .tint(.emberStrong)
                .disabled(working)
                .accessibilityIdentifier("linkAllow")
                Button("Don't allow", action: onDeny)
                    .foregroundStyle(.emberText)
                    .frame(minHeight: Spacing.minHitTarget)
            }
        }
        .folioHaptic(.success, trigger: done)
    }
}
