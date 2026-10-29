import SwiftUI
import UIKit

/// What the system tab bar shows right now, in window coordinates (Batch C fix).
nonisolated struct TabBarShape: Equatable, Sendable {
    /// Top edge of the tab bar's area: where content above it ends.
    var top: Double
    /// The visible glass platter: the full bar, or the small circle once minimised.
    var platter: CGRect
    var isMinimised: Bool
}

/// Reads the tab bar's live shape so the To-do quick-add bar can follow it when the bar
/// minimises on scroll. iOS 26 has no public "is minimised" signal (`tabViewBottomAccessoryPlacement`
/// only reaches views inside the accessory), so this looks at which of the bar's own subviews
/// is visible, using public `UIView` state only. If the bar can't be read it reports `nil`
/// and the quick-add bar stays where it is.
///
/// It only polls (one display link) while `isTracking` is on, plus a short settle after,
/// because the bar minimises and expands only in response to scrolling.
struct TabBarShapeReader: UIViewRepresentable {
    var isTracking: Bool
    var onChange: (TabBarShape?) -> Void

    func makeUIView(context: Context) -> ReaderView {
        ReaderView()
    }

    func updateUIView(_ view: ReaderView, context: Context) {
        view.onChange = onChange
        view.setTracking(isTracking)
    }

    final class ReaderView: UIView {
        var onChange: ((TabBarShape?) -> Void)?
        private var link: CADisplayLink?
        private var isTracking = false
        private var settleUntil = ContinuousClock.now
        private var last: TabBarShape?

        /// The minimise/expand morph finishes a little after scrolling stops.
        private static let settle: Duration = .milliseconds(800)

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            isAccessibilityElement = false
        }

        required init?(coder: NSCoder) { fatalError("not used") }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window == nil { stopLink() } else { read() }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            read()
        }

        func setTracking(_ tracking: Bool) {
            guard tracking != isTracking else { return }
            isTracking = tracking
            if !tracking { settleUntil = .now + Self.settle }
            startLink()
        }

        private func startLink() {
            guard link == nil, window != nil else { return }
            let link = CADisplayLink(target: self, selector: #selector(tick))
            link.add(to: .main, forMode: .common)
            self.link = link
        }

        private func stopLink() {
            link?.invalidate()
            link = nil
        }

        @objc private func tick() {
            read()
            if !isTracking, ContinuousClock.now > settleUntil { stopLink() }
        }

        private func read() {
            let shape = currentShape()
            guard shape != last else { return }
            last = shape
            onChange?(shape)
        }

        private func currentShape() -> TabBarShape? {
            var responder: UIResponder? = self
            while let next = responder?.next, !(next is UITabBarController) { responder = next }
            guard let bar = (responder?.next as? UITabBarController)?.tabBar,
                  !bar.isHidden, bar.window != nil else { return nil }
            // The platters are the bar's direct subviews that fit inside it; a minimised bar
            // hides the wide one and shows a small circle.
            let platter = bar.subviews
                .filter { !$0.isHidden && $0.alpha > 0.01 && $0.bounds.width >= 40 && $0.frame.height <= bar.bounds.height }
                .max { $0.bounds.width < $1.bounds.width }
            guard let platter else { return nil }
            let frame = bar.convert(platter.frame, to: nil)
            return TabBarShape(top: bar.convert(bar.bounds, to: nil).minY, platter: frame,
                               isMinimised: frame.width < bar.bounds.width / 2)
        }
    }
}
