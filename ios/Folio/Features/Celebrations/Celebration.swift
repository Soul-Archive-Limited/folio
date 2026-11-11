import SwiftUI

/// Gentle celebrations (Batch N Part 4). No streaks, no counters: a moment on the calendar day
/// it's about, under a second, interruptible, a simple fade with Reduce Motion, and off with
/// Profile → Appearance → Celebrations (device-only, default on).
struct Celebration: Equatable, Sendable {
    enum Kind: Sendable {
        /// The first page kept for today (or a coming day): a soft Ink bloom around the day.
        case bloom
        /// The first page kept for a past day: the day settles like a page laid down.
        case settle
        /// Every task that day is done: the task ring fills, with a small sparkle.
        case tasksDone
    }

    let id = UUID()
    let kind: Kind
    let day: DayKey

    static let settingKey = "celebrations"

    /// Whether this device shows celebrations (Appearance → Celebrations).
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: settingKey) as? Bool ?? true
    }

    /// The quiet line for a first page.
    static func savedLine(for day: DayKey, today: DayKey) -> LocalizedStringResource {
        if day == today { return "Today's page is kept." }
        let date = day.utcDate.formatted(Date.FormatStyle(timeZone: .gmt).weekday(.wide).day().month(.wide))
        // Batch O (independent review): a page written ahead isn't "kept" yet.
        if day > today { return "Saved for \(date)." }
        return "Kept on \(date)."
    }
}

extension DiaryStore {
    /// Plays `kind` on `day` if celebrations are on. Never for changes arriving from sync.
    func celebrate(_ kind: Celebration.Kind, on day: DayKey) {
        guard Celebration.isEnabled, !isApplyingRemote else { return }
        celebration = Celebration(kind: kind, day: day)
    }

    /// After a task is ticked: if that was the last open task of its day, the ring fills.
    func celebrateIfDayDone(after task: TaskItem) {
        guard task.isCompleted, task.parentID == nil, let raw = task.dayKey, let day = DayKey(rawValue: raw) else { return }
        let tasks = tasks(on: day)
        guard !tasks.isEmpty, tasks.allSatisfy(\.isCompleted) else { return }
        celebrate(.tasksDone, on: day)
    }
}

/// What a day cell draws over itself for celebrations. Always in place (transparent at rest):
/// `keyframeAnimator` plays only when its trigger *changes* after the view exists, so an overlay
/// inserted together with its trigger would never play. Each effect has its own play count.
struct CelebrationOverlay: View {
    let bloomPlays: Int
    let bloomStrength: Double
    let sparklePlays: Int
    let size: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            bloom
            sparkle
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// A soft Ink ring that breathes out from the day and fades — 0.8 s. Reduce Motion: it only
    /// fades in and out, without growing. A past day's settle uses a fainter one.
    private var bloom: some View {
        let strength = bloomStrength
        let still = reduceMotion
        // A ring with a soft glow, never a wash over the day's photo or number.
        return RoundedRectangle(cornerRadius: Radius.dayCell + 4)
            .strokeBorder(Color.accent, lineWidth: 2)
            .shadow(color: Color.accent.opacity(0.6), radius: 6)
            .frame(width: size, height: size)
            .keyframeAnimator(initialValue: BloomFrame(), trigger: bloomPlays) { content, frame in
                content.scaleEffect(still ? 1 : frame.scale).opacity(frame.opacity * strength)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    CubicKeyframe(0.82, duration: 0.01)
                    SpringKeyframe(1.32, duration: 0.8, spring: .smooth(duration: 0.8))
                }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(1, duration: 0.12)
                    CubicKeyframe(0, duration: 0.68)
                }
            }
    }

    /// Four short Ink rays that flick out from the task mark — 0.7 s.
    private var sparkle: some View {
        let still = reduceMotion
        return ZStack {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(Color.accent)
                    .frame(width: 1.5, height: 4)
                    .offset(y: -7)
                    .rotationEffect(.degrees(Double(index) * 90 + 45))
            }
        }
        .frame(width: 18, height: 18)
        .keyframeAnimator(initialValue: BloomFrame(), trigger: sparklePlays) { content, frame in
            content.scaleEffect(still ? 1 : frame.scale).opacity(frame.opacity)
        } keyframes: { _ in
            KeyframeTrack(\.scale) {
                CubicKeyframe(0.4, duration: 0.01)
                SpringKeyframe(1.25, duration: 0.7, spring: .snappy(duration: 0.5))
            }
            KeyframeTrack(\.opacity) {
                LinearKeyframe(1, duration: 0.15)
                CubicKeyframe(0, duration: 0.55)
            }
        }
        .padding(TaskCornerMark.inset - 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }
}

struct BloomFrame {
    var scale = 1.0
    var opacity = 0.0
}

/// The page-settling motion for a past day: the cell lifts a touch, tilts, and lays itself down
/// with a soft shadow — 0.7 s. Reduce Motion: nothing moves (the faint bloom still fades).
struct PageSettle: ViewModifier {
    let trigger: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let still = reduceMotion
        return content.keyframeAnimator(initialValue: SettleFrame(), trigger: trigger) { view, frame in
            view
                .offset(y: still ? 0 : frame.lift)
                .rotationEffect(.degrees(still ? 0 : frame.tilt), anchor: .bottomLeading)
                .shadow(color: .black.opacity(still ? 0 : frame.shadow), radius: 6, y: 3)
        } keyframes: { _ in
            KeyframeTrack(\.lift) {
                CubicKeyframe(-5, duration: 0.18)
                SpringKeyframe(0, duration: 0.5, spring: .bouncy(duration: 0.5, extraBounce: 0.05))
            }
            KeyframeTrack(\.tilt) {
                CubicKeyframe(-2.5, duration: 0.18)
                SpringKeyframe(0, duration: 0.5, spring: .smooth(duration: 0.5))
            }
            KeyframeTrack(\.shadow) {
                LinearKeyframe(0.18, duration: 0.18)
                CubicKeyframe(0, duration: 0.5)
            }
        }
    }
}

struct SettleFrame {
    var lift = 0.0
    var tilt = 0.0
    var shadow = 0.0
}
