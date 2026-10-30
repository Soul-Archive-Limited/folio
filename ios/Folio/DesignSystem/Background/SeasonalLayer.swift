import SwiftUI

/// The aura's seasonal layer (Batch I): blossom drifting in spring, a warm glow in summer, rain
/// streaks in the monsoon, leaves in autumn, snowflakes in winter. Barely there: a dozen small
/// shapes at low opacity, only in the top band of the screen (faded out before the content),
/// behind every view, 20 fps at most. Off under Reduce Motion, in Low Power Mode and while the
/// app isn't active (≤ 2 % CPU when on).
struct SeasonalLayer: View {
    let season: Season

    @Environment(\.colorScheme) private var colorScheme

    /// How far down the screen the effect reaches before fading out completely.
    static let band = 0.34
    static let particles = 12

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            Canvas { canvas, size in
                let height = size.height * Self.band
                switch season {
                case .summer: drawGlow(in: &canvas, size: size, time: time)
                default:
                    for index in 0..<Self.particles {
                        drawParticle(index, in: &canvas, width: size.width, height: height, time: time)
                    }
                }
            }
        }
        .mask {
            LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: Self.band * 0.55),
                                   .init(color: .clear, location: Self.band)],
                           startPoint: .top, endPoint: .bottom)
        }
        .opacity(colorScheme == .dark ? 0.55 : 0.7)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Repeatable pseudo-random numbers per particle.
    private func random(_ index: Int, _ salt: Int) -> Double {
        let x = sin(Double(index * 127 + salt * 311) * 12.9898) * 43758.5453
        return x - x.rounded(.down)
    }

    private func drawParticle(_ i: Int, in canvas: inout GraphicsContext, width: Double, height: Double, time: Double) {
        let speed: Double = switch season {
        case .monsoon: 140 + 60 * random(i, 1)
        case .winter: 10 + 8 * random(i, 1)
        default: 14 + 10 * random(i, 1)
        }
        let travel = height + 40
        let progress = (time * speed / travel + random(i, 2)).truncatingRemainder(dividingBy: 1)
        let y = progress * travel - 20
        let sway = season == .monsoon ? 0 : sin(time / (3 + 2 * random(i, 3)) + random(i, 4) * 6) * 14
        let drift = season == .monsoon ? progress * 30 : progress * 22
        let x = random(i, 5) * width + sway + drift
        let size = 3 + 4 * random(i, 6)
        var context = canvas
        context.translateBy(x: x, y: y)
        switch season {
        case .spring:
            context.rotate(by: .radians(time / 4 + random(i, 7) * 6))
            let petal = Path(ellipseIn: CGRect(x: -size, y: -size / 2, width: size * 2, height: size))
            context.fill(petal, with: .color(Color(red: 1, green: 0.72, blue: 0.80).opacity(0.55)))
        case .autumn:
            context.rotate(by: .radians(time / 3 + random(i, 7) * 6))
            var leaf = Path()
            leaf.move(to: CGPoint(x: -size * 1.2, y: 0))
            leaf.addQuadCurve(to: CGPoint(x: size * 1.2, y: 0), control: CGPoint(x: 0, y: -size * 1.1))
            leaf.addQuadCurve(to: CGPoint(x: -size * 1.2, y: 0), control: CGPoint(x: 0, y: size * 1.1))
            let tone = random(i, 8)
            context.fill(leaf, with: .color(Color(red: 0.95, green: 0.45 + tone * 0.3, blue: 0.15).opacity(0.5)))
        case .winter:
            let flake = Path(ellipseIn: CGRect(x: -size / 2, y: -size / 2, width: size, height: size))
            let snow = colorScheme == .dark ? Color.white.opacity(0.7) : Color(red: 0.62, green: 0.72, blue: 0.86).opacity(0.6)
            context.fill(flake, with: .color(snow))
        case .monsoon:
            var streak = Path()
            streak.move(to: .zero)
            streak.addLine(to: CGPoint(x: -4, y: 14 + size * 2))
            let rain = colorScheme == .dark ? Color.white.opacity(0.35) : Color(red: 0.4, green: 0.55, blue: 0.75).opacity(0.4)
            context.stroke(streak, with: .color(rain), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
        case .summer:
            break
        }
    }

    /// Summer: a warm glow in the top corner that breathes very slowly, plus a few motes rising.
    private func drawGlow(in canvas: inout GraphicsContext, size: CGSize, time: Double) {
        let breathe = 0.85 + 0.15 * sin(time / 6)
        let center = CGPoint(x: size.width * 0.85, y: size.height * 0.04)
        let radius = size.width * 0.75 * breathe
        let warm = Color(red: 1, green: 0.78, blue: 0.42)
        canvas.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                    with: .radialGradient(Gradient(colors: [warm.opacity(0.35), warm.opacity(0)]), center: center,
                                          startRadius: 0, endRadius: radius))
        for i in 0..<6 {
            let travel = size.height * Self.band
            let progress = (time * (6 + 4 * random(i, 1)) / travel + random(i, 2)).truncatingRemainder(dividingBy: 1)
            let point = CGPoint(x: random(i, 5) * size.width + sin(time / 4 + Double(i)) * 10, y: travel * (1 - progress))
            canvas.fill(Path(ellipseIn: CGRect(x: point.x - 1.5, y: point.y - 1.5, width: 3, height: 3)),
                        with: .color(warm.opacity(0.6)))
        }
    }
}
