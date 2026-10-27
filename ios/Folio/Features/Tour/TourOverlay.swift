import SwiftUI

extension View {
    /// Reports this view's frame as the anchor for a tour step.
    func tourAnchor(_ step: TourStep, _ tour: TourModel?) -> some View {
        onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
            tour?.anchors[step] = frame
        }
    }

    /// Draws the current tour card when it belongs to this surface: the main tab view, or the
    /// composer sheet (a sheet is its own presentation, so it needs its own host).
    func tourHost(_ host: TourStep.Host, _ tour: TourModel?) -> some View {
        overlay {
            if let tour { TourOverlay(host: host, tour: tour) }
        }
    }
}

/// Places the card next to its anchor (below when there's room, else above) and rings the
/// anchor so it's clear what the step is about. Only the card takes touches.
private struct TourOverlay: View {
    let host: TourStep.Host
    let tour: TourModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var cardHeight: Double = 190

    /// The floating iPhone tab bar's side inset and height (iOS 26), measured.
    private static let barInset: Double = 22
    private static let barHeight: Double = 62

    var body: some View {
        GeometryReader { proxy in
            if let step = tour.visible, step.host == host {
                let target = anchor(for: step, in: proxy)
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: highlightRadius(step, target))
                        .strokeBorder(.ember, lineWidth: 2.5)
                        .shadow(color: .ember.opacity(0.45), radius: 8)
                        .frame(width: target.width + 8, height: target.height + 8)
                        .offset(x: target.minX - 4, y: target.minY - 4)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    TourCard(step: step, tour: tour)
                        .onGeometryChange(for: Double.self) { $0.size.height } action: { cardHeight = $0 }
                        .padding(.horizontal, Spacing.m)
                        .frame(width: proxy.size.width)
                        .offset(y: cardY(below: target, in: proxy.size))
                }
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96)))
                .id(step)
            }
        }
        .animation(reduceMotion ? FolioMotion.reduced : .smooth(duration: 0.3), value: tour.visible)
    }

    private func anchor(for step: TourStep, in proxy: GeometryProxy) -> CGRect {
        switch step {
        case .todo: return tabItem(2, in: proxy.size)
        case .profile: return tabItem(3, in: proxy.size)
        default:
            let origin = proxy.frame(in: .global).origin
            let frame = tour.anchors[step] ?? .zero
            return frame.offsetBy(dx: -origin.x, dy: -origin.y)
        }
    }

    /// The system tab bar can't anchor anything itself, so its items are measured from the
    /// bar's known shape.
    private func tabItem(_ index: Int, in size: CGSize) -> CGRect {
        let itemWidth = (size.width - Self.barInset * 2) / Double(AppTab.allCases.count)
        return CGRect(x: Self.barInset + itemWidth * Double(index) + 4, y: size.height - Self.barHeight + 6,
                      width: itemWidth - 8, height: Self.barHeight - 12)
    }

    private func highlightRadius(_ step: TourStep, _ target: CGRect) -> Double {
        switch step {
        case .month: Radius.card
        case .tapDay: Radius.dayCell
        default: min(target.width, target.height) / 2 + 4
        }
    }

    private func cardY(below target: CGRect, in size: CGSize) -> Double {
        let gap = Spacing.m
        if target.maxY + gap + cardHeight <= size.height - Spacing.s { return target.maxY + gap }
        return max(target.minY - gap - cardHeight, Spacing.s)
    }
}
