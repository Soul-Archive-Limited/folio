#if DEBUG
import QuartzCore
import UIKit

/// DEBUG-only frame monitor for the Phase 13 hitch audit (`-FolioHitchLog YES`). Instruments'
/// Animation Hitches needs a device, so on the Simulator this counts frames that arrived later
/// than the display asked for — main-thread stalls — and writes a summary per second to
/// `Documents/hitches.log` in the app's container.
final class HitchMonitor: NSObject {
    static let shared = HitchMonitor()

    private var link: CADisplayLink?
    private var expected: CFTimeInterval = 0
    private var windowStart: CFTimeInterval = 0
    private var frames = 0
    private var hitches = 0
    private var hitchTime: CFTimeInterval = 0
    private var worst: CFTimeInterval = 0
    private var lines: [String] = []

    func start() {
        guard link == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        self.link = link
        lines.append("# unix_time,frames,hitches,hitch_ms,worst_ms")
    }

    /// Splits the log by flow: `# mark <name> <unix time>`.
    func mark(_ name: String) {
        lines.append(String(format: "# mark %@ %.2f", name, Date().timeIntervalSince1970))
        flush()
    }

    @objc private func tick(_ link: CADisplayLink) {
        let now = link.timestamp
        let duration = link.targetTimestamp - link.timestamp
        if expected > 0 {
            // A frame is a hitch when it lands more than half a frame after it was due.
            let late = now - expected
            if late > duration * 0.5 {
                hitches += 1
                hitchTime += late
                worst = max(worst, late)
            }
        }
        expected = link.targetTimestamp
        frames += 1
        if windowStart == 0 { windowStart = now }
        if now - windowStart >= 1 {
            lines.append(String(format: "%.1f,%d,%d,%.1f,%.1f", Date().timeIntervalSince1970, frames, hitches, hitchTime * 1000, worst * 1000))
            frames = 0; hitches = 0; hitchTime = 0; worst = 0
            windowStart = now
            flush()
        }
    }

    private func flush() {
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appending(path: "hitches.log") else { return }
        try? lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }
}
#endif
