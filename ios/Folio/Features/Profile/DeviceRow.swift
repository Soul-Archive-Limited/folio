import SwiftUI

/// One device in Profile → Devices: the person's name for it (or its model and OS), the
/// model under a custom name, when it was added and last seen, and a "This device" badge.
struct DeviceRow: View {
    let device: AccountAPI.Device
    let label: String?

    var body: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: symbol)
                .foregroundStyle(.ember)
                .frame(width: 26)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(label ?? device.name).foregroundStyle(.ink)
                if label != nil {
                    Text(device.name).folioFont(.callout).foregroundStyle(.inkSecondary)
                }
                Text(details)
                    .folioFont(.callout)
                    .foregroundStyle(.inkTertiary)
            }
            Spacer(minLength: Spacing.xs)
            if device.current {
                Text("This device")
                    .folioFont(.caption)
                    .foregroundStyle(.emberText)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.ember.opacity(0.14)))
            }
        }
        .folioFont(.body)
        .frame(minHeight: Spacing.minHitTarget)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        if device.platform == "web" { return "globe" }
        return device.name.hasPrefix("iPad") ? "ipad" : "iphone"
    }

    /// "Added 12 Oct 2026 · Last seen 3 hours ago". The server notes activity at most once an
    /// hour, so anything newer reads "Active in the last hour".
    private var details: String {
        let added = Date(timeIntervalSince1970: device.createdAt / 1000)
        let seen = Date(timeIntervalSince1970: device.lastSeenAt / 1000)
        let addedText = "Added \(added.formatted(.dateTime.day().month(.abbreviated).year()))"
        if device.current { return addedText }
        let seenText = Date.now.timeIntervalSince(seen) < 3600
            ? String(localized: "Active in the last hour")
            : String(localized: "Last seen \(seen.formatted(.relative(presentation: .named)))")
        return "\(addedText) · \(seenText)"
    }
}
