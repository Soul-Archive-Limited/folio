import SwiftUI

/// One blob of the aura: where it sits, how far and how slowly it drifts.
struct AuraBlob: Sendable {
    let color: ColorResource
    /// Resting centre as a fraction of the canvas.
    let anchor: UnitPoint
    let radius: Double
    /// Drift distance in points.
    let amplitude: Double
    /// Seconds for one loop of the drift path (18–30 s).
    let period: Double
    let phase: Double

    static let all: [AuraBlob] = [
        AuraBlob(color: .aura1, anchor: UnitPoint(x: 0.15, y: 0.12), radius: 320, amplitude: 70, period: 22, phase: 0),
        AuraBlob(color: .aura2, anchor: UnitPoint(x: 0.95, y: 0.45), radius: 300, amplitude: 80, period: 28, phase: 2.1),
        AuraBlob(color: .aura3, anchor: UnitPoint(x: 0.30, y: 0.92), radius: 340, amplitude: 60, period: 18, phase: 4.2),
    ]

    /// Soft-edge width that stands in for the 90 pt blur.
    static let softness: Double = 90

    func center(in size: CGSize, time: TimeInterval) -> CGPoint {
        let angle = (time / period) * 2 * .pi + phase
        return CGPoint(
            x: anchor.x * size.width + amplitude * sin(angle),
            y: anchor.y * size.height + amplitude * cos(angle * 0.77)
        )
    }

    func draw(in canvas: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let center = center(in: size, time: time)
        let outer = radius + Self.softness
        let rect = CGRect(x: center.x - outer, y: center.y - outer, width: outer * 2, height: outer * 2)
        let base = Color(color)
        let gradient = Gradient(stops: [
            .init(color: base, location: 0),
            .init(color: base, location: (radius - Self.softness) / outer),
            .init(color: base.opacity(0.5), location: radius / outer),
            .init(color: base.opacity(0), location: 1),
        ])
        canvas.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(gradient, center: center, startRadius: 0, endRadius: outer)
        )
    }

    /// A gentle seasonal hue shift of up to ±18° across the year.
    static func seasonalHueShift(month: Int) -> Double {
        18 * sin(Double(month - 1) / 12 * 2 * .pi)
    }
}
