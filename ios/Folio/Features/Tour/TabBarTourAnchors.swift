import SwiftUI

/// Invisible anchors just above the To-do and Profile tab items, for tour steps 4 and 5
/// (SPEC §6.15). The system tab bar can't host a popover itself, so the tips point at the
/// spot above each item instead. The overlay doesn't take touches.
struct TabBarTourAnchors: View {
    let tour: TourModel?

    /// The floating tab bar's side inset and height on iPhone (iOS 26), measured.
    private static let barInset: Double = 22
    private static let barHeight: Double = 62

    var body: some View {
        GeometryReader { proxy in
            let itemWidth = (proxy.size.width - Self.barInset * 2) / Double(AppTab.allCases.count)
            ZStack(alignment: .bottomLeading) {
                anchor.tourTip(TodoTabTip.self, tour, arrowEdge: .bottom)
                    .offset(x: Self.barInset + itemWidth * 2.5)
                anchor.tourTip(ProfileTabTip.self, tour, arrowEdge: .bottom)
                    .offset(x: Self.barInset + itemWidth * 3.5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(.bottom, Self.barHeight)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var anchor: some View {
        Color.clear.frame(width: 1, height: 1)
    }
}
