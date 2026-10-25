import SwiftUI

/// The slowly drifting colour aura behind glass (SPEC §3.5).
///
/// Three soft blobs drift on 18–30 s paths. Each blob is a radial gradient with a soft
/// edge rather than a live Gaussian blur: it looks the same as a 90 pt blur and costs a
/// fraction of the GPU time (DECISIONS.md, Phase 1). Static under Reduce Motion, paused
/// while the app isn't active.
struct AuraBackground: View {
    /// Month (1–12) for the seasonal hue shift; defaults to the current month.
    var month: Int = Calendar.current.component(.month, from: .now)
    /// Freezes the drift (screenshots, previews of static states).
    var isFrozen = false

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: isPaused)) { context in
            let time = isPaused ? 0 : context.date.timeIntervalSinceReferenceDate
            Canvas { canvas, size in
                for blob in AuraBlob.all {
                    blob.draw(in: &canvas, size: size, time: time)
                }
            }
        }
        .opacity(colorScheme == .dark ? 0.14 : 0.22)
        .hueRotation(.degrees(AuraBlob.seasonalHueShift(month: month)))
        .background(.bg)
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private var isPaused: Bool {
        isFrozen || reduceMotion || scenePhase != .active
    }
}

#Preview("Light") {
    AuraBackground()
}

#Preview("Dark") {
    AuraBackground()
        .preferredColorScheme(.dark)
}
