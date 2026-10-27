import SwiftUI
import UIKit

/// A pan that only starts when the finger moves mostly sideways, so cards inside a vertical
/// `ScrollView` can be swiped without stealing the scroll. SwiftUI's `DragGesture` can't
/// decline a vertical start; a UIKit recogniser can (`gestureRecognizerShouldBegin`).
struct HorizontalPanGesture: UIGestureRecognizerRepresentable {
    var onChanged: (Double) -> Void
    var onEnded: (_ translation: Double, _ velocity: Double) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        return pan
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let translation = recognizer.translation(in: recognizer.view).x
        switch recognizer.state {
        case .changed: onChanged(translation)
        case .ended: onEnded(translation, recognizer.velocity(in: recognizer.view).x)
        case .cancelled, .failed: onEnded(0, 0)
        default: break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let pan = recognizer as? UIPanGestureRecognizer else { return true }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y) * 1.3
        }
    }
}
