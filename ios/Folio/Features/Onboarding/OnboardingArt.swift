import SwiftUI

/// Page 1: a month grid assembling tile by tile, with a few sample photo tiles.
struct AssemblingMonthArt: View {
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = 0

    private static let count = 35
    /// Which tiles carry a photo, and which a category dot.
    private static let photoTiles: [Int: Int] = [3: 1, 9: 4, 12: 2, 18: 6, 23: 3, 27: 5, 31: 7]
    private static let dotTiles: [Int: CategoryColor] = [1: .ocean, 6: .rose, 15: .sage, 20: .violet, 25: .ember, 29: .teal]

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(0..<Self.count, id: \.self) { index in
                tile(index)
                    .aspectRatio(1, contentMode: .fit)
                    .scaleEffect(index < shown || reduceMotion ? 1 : 0.6)
                    .opacity(index < shown ? 1 : 0)
            }
        }
        .padding(Spacing.m)
        .folioGlass(in: .rect(cornerRadius: Radius.card))
        .padding(.horizontal, Spacing.xxl)
        .task(id: isActive) { await assemble() }
    }

    @ViewBuilder
    private func tile(_ index: Int) -> some View {
        let shape = RoundedRectangle(cornerRadius: 8)
        if let seed = Self.photoTiles[index] {
            MiniLandscape(seed: seed).clipShape(shape)
        } else {
            shape.fill(.bgElevated.opacity(0.7))
                .overlay(alignment: .bottom) {
                    if let color = Self.dotTiles[index] {
                        Circle().fill(color.color).frame(width: 5, height: 5).padding(.bottom, 5)
                    }
                }
                .overlay(alignment: .topLeading) {
                    Text("\(index + 1 <= 31 ? index + 1 : index - 30)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.inkTertiary)
                        .padding(4)
                }
        }
    }

    private func assemble() async {
        guard isActive, shown < Self.count else { return }
        if reduceMotion {
            withAnimation(FolioMotion.reduced) { shown = Self.count }
            return
        }
        for index in shown...Self.count {
            try? await Task.sleep(for: .milliseconds(28))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(duration: 0.4, bounce: 0.3)) { shown = index }
        }
    }
}

/// A tiny drawn landscape standing in for a photo: sky, sun and two hills.
struct MiniLandscape: View {
    let seed: Int

    private static let palettes: [(sky: [Color], hills: [Color], sun: Color)] = [
        ([Color(red: 0.98, green: 0.74, blue: 0.56), Color(red: 0.86, green: 0.6, blue: 0.5)],
         [Color(red: 0.36, green: 0.45, blue: 0.38), Color(red: 0.25, green: 0.31, blue: 0.27)], Color(red: 1, green: 0.9, blue: 0.65)),
        ([Color(red: 0.6, green: 0.78, blue: 0.93), Color(red: 0.82, green: 0.9, blue: 0.96)],
         [Color(red: 0.45, green: 0.6, blue: 0.4), Color(red: 0.3, green: 0.45, blue: 0.32)], Color(red: 1, green: 0.97, blue: 0.85)),
        ([Color(red: 0.42, green: 0.36, blue: 0.62), Color(red: 0.86, green: 0.55, blue: 0.58)],
         [Color(red: 0.3, green: 0.24, blue: 0.4), Color(red: 0.2, green: 0.16, blue: 0.28)], Color(red: 1, green: 0.82, blue: 0.7)),
        ([Color(red: 0.95, green: 0.86, blue: 0.62), Color(red: 0.93, green: 0.7, blue: 0.45)],
         [Color(red: 0.62, green: 0.5, blue: 0.32), Color(red: 0.45, green: 0.35, blue: 0.22)], Color(red: 1, green: 0.95, blue: 0.8)),
    ]

    var body: some View {
        let palette = Self.palettes[abs(seed) % Self.palettes.count]
        Canvas { context, size in
            let w = size.width, h = size.height
            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .linearGradient(Gradient(colors: palette.sky), startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
            let sunX = w * (0.25 + Double(seed % 3) * 0.2)
            context.fill(Path(ellipseIn: CGRect(x: sunX, y: h * 0.18, width: w * 0.24, height: w * 0.24)), with: .color(palette.sun))
            for (index, color) in palette.hills.enumerated() {
                var hill = Path()
                let base = h * (0.55 + Double(index) * 0.15)
                hill.move(to: CGPoint(x: 0, y: base))
                hill.addCurve(to: CGPoint(x: w, y: base - h * 0.08),
                              control1: CGPoint(x: w * 0.3, y: base - h * 0.25), control2: CGPoint(x: w * 0.6, y: base + h * 0.1))
                hill.addLine(to: CGPoint(x: w, y: h))
                hill.addLine(to: CGPoint(x: 0, y: h))
                context.fill(hill, with: .color(color))
            }
        }
    }
}
