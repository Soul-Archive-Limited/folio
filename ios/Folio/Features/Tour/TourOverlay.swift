import SwiftUI
import UIKit

extension View {
    /// Reports this view's frame as the anchor for a tour step, measured in its host's own
    /// coordinate space. (The composer is a sheet that moves and scales while it presents, so
    /// screen coordinates put step 4's ring off its tool row — owner's test, Batch I.)
    func tourAnchor(_ step: TourStep, _ tour: TourModel?) -> some View {
        let host = step.host
        return onGeometryChange(for: CGRect.self) { $0.frame(in: host.coordinateSpace) } action: { frame in
            tour?.anchors[step] = frame
        }
    }

    /// Draws the current tour card when it belongs to this surface: the main tab view, or the
    /// composer sheet (a sheet is its own presentation, so it needs its own host).
    func tourHost(_ host: TourStep.Host, _ tour: TourModel?) -> some View {
        coordinateSpace(host.coordinateSpace)
            .overlay {
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
    /// The tab bar's glass platter in window coordinates, read from the bar itself.
    @State private var tabPlatter: CGRect?

    /// Even space between a target and its ring; the ring's corners stay concentric.
    private static let ringInset: Double = 6

    var body: some View {
        GeometryReader { proxy in
            if let step = tour.visible, step.host == host {
                let target = anchor(for: step, in: proxy)
                let ring = target.insetBy(dx: -Self.ringInset, dy: -Self.ringInset)
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: highlightRadius(step, target) + Self.ringInset, style: .continuous)
                        .strokeBorder(.ember, lineWidth: 2.5)
                        .shadow(color: .ember.opacity(0.45), radius: 8)
                        .frame(width: ring.width, height: ring.height)
                        .offset(x: ring.minX, y: ring.minY)
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
        .background {
            if host == .main {
                TabBarPlatterReader { tabPlatter = $0 }.allowsHitTesting(false).accessibilityHidden(true)
            }
        }
        .animation(reduceMotion ? FolioMotion.reduced : .smooth(duration: 0.3), value: tour.visible)
    }

    private func anchor(for step: TourStep, in proxy: GeometryProxy) -> CGRect {
        switch step {
        case .todo: return tabItem(2, in: proxy)
        case .profile: return tabItem(3, in: proxy)
        default:
            let origin = proxy.frame(in: host.coordinateSpace).origin
            let frame = tour.anchors[step] ?? .zero
            return frame.offsetBy(dx: -origin.x, dy: -origin.y)
        }
    }

    /// The system tab bar can't anchor anything itself: its items are measured from the bar's
    /// live glass platter (equal slots, the selection pill's inset), on every screen size.
    private func tabItem(_ index: Int, in proxy: GeometryProxy) -> CGRect {
        let origin = proxy.frame(in: .global).origin
        let platter = (tabPlatter ?? CGRect(x: 21, y: proxy.size.height - 62, width: proxy.size.width - 42, height: 62))
            .offsetBy(dx: -origin.x, dy: -origin.y)
        let pad = 4.0
        let slot = (platter.width - pad * 2) / Double(AppTab.allCases.count)
        return CGRect(x: platter.minX + pad + slot * Double(index), y: platter.minY + pad,
                      width: slot, height: platter.height - pad * 2)
    }

    /// The target's own corner radius; the ring adds its inset to stay concentric.
    private func highlightRadius(_ step: TourStep, _ target: CGRect) -> Double {
        switch step {
        case .month: Radius.card
        case .tapDay: Radius.dayCell
        default: min(target.width, target.height) / 2
        }
    }

    private func cardY(below target: CGRect, in size: CGSize) -> Double {
        let gap = Spacing.m
        if target.maxY + gap + cardHeight <= size.height - Spacing.s { return target.maxY + gap }
        return max(target.minY - gap - cardHeight, Spacing.s)
    }
}

nonisolated extension TourStep.Host {
    var coordinateSpace: NamedCoordinateSpace {
        switch self {
        case .main: .named("tour.main")
        case .composer: .named("tour.composer")
        }
    }
}

/// Finds the window's tab bar and reports its visible glass platter (window coordinates).
private struct TabBarPlatterReader: UIViewRepresentable {
    var onChange: (CGRect?) -> Void

    func makeUIView(context: Context) -> ReaderView { ReaderView() }

    func updateUIView(_ view: ReaderView, context: Context) {
        view.onChange = onChange
        view.setNeedsLayout()
    }

    final class ReaderView: UIView {
        var onChange: ((CGRect?) -> Void)?
        private var last: CGRect?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            report()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            // The tab bar lays out after this overlay on first appearance.
            DispatchQueue.main.async { [weak self] in self?.report() }
        }

        private func report() {
            guard let window, let bar = Self.tabBar(in: window) else { return }
            let platter = bar.subviews
                .filter { !$0.isHidden && $0.alpha > 0.01 && $0.bounds.width >= 40 && $0.frame.height <= bar.bounds.height }
                .max { $0.bounds.width < $1.bounds.width }
            let frame = platter.map { bar.convert($0.frame, to: nil) }
            guard frame != last else { return }
            last = frame
            onChange?(frame)
        }

        private static func tabBar(in view: UIView) -> UITabBar? {
            if let bar = view as? UITabBar, !bar.isHidden { return bar }
            for sub in view.subviews { if let bar = tabBar(in: sub) { return bar } }
            return nil
        }
    }
}
