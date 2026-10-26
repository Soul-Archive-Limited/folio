#if DEBUG
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Draws simple landscape-style placeholder photos for sample data (no bundled images, no
/// network). Output is JPEG, then goes through the real `PhotoProcessor`.
nonisolated enum SampleImageRenderer {
    struct Palette: Sendable {
        let sky: (Double, Double, Double)
        let ground: (Double, Double, Double)
        let sun: (Double, Double, Double)
    }

    static let palettes: [Palette] = [
        Palette(sky: (0.98, 0.72, 0.55), ground: (0.36, 0.45, 0.38), sun: (1.0, 0.92, 0.70)),
        Palette(sky: (0.55, 0.74, 0.95), ground: (0.20, 0.42, 0.60), sun: (1.0, 1.0, 0.95)),
        Palette(sky: (0.80, 0.70, 0.95), ground: (0.42, 0.30, 0.55), sun: (1.0, 0.85, 0.80)),
        Palette(sky: (0.95, 0.85, 0.65), ground: (0.70, 0.52, 0.30), sun: (1.0, 0.60, 0.35)),
        Palette(sky: (0.60, 0.85, 0.80), ground: (0.10, 0.45, 0.42), sun: (0.98, 0.98, 0.90)),
        Palette(sky: (0.25, 0.28, 0.45), ground: (0.10, 0.10, 0.18), sun: (0.95, 0.92, 0.80)),
    ]

    static func jpeg(seed: Int, width: Int = 1600, height: Int = 1200) -> Data? {
        let palette = palettes[abs(seed) % palettes.count]
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        let w = Double(width), h = Double(height)
        func color(_ c: (Double, Double, Double), _ a: Double = 1) -> CGColor { CGColor(srgbRed: c.0, green: c.1, blue: c.2, alpha: a) }

        let sky = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [
            color(palette.sky), color((palette.sky.0 * 0.85, palette.sky.1 * 0.85, palette.sky.2 * 0.95)),
        ] as CFArray, locations: [0, 1])!
        context.drawLinearGradient(sky, start: CGPoint(x: 0, y: h), end: CGPoint(x: 0, y: h * 0.3), options: [])

        let sunX = w * (0.2 + Double(abs(seed * 37) % 60) / 100)
        context.setFillColor(color(palette.sun, 0.95))
        context.fillEllipse(in: CGRect(x: sunX - h * 0.1, y: h * 0.55, width: h * 0.2, height: h * 0.2))

        for layer in 0..<3 {
            let shade = 1 - Double(layer) * 0.18
            context.setFillColor(color((palette.ground.0 * shade, palette.ground.1 * shade, palette.ground.2 * shade)))
            let path = CGMutablePath()
            let base = h * (0.42 - Double(layer) * 0.12)
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 0, y: base))
            for step in 0...8 {
                let x = w * Double(step) / 8
                let wave = sin(Double(step + seed + layer * 3) * 1.3) * h * 0.06
                path.addLine(to: CGPoint(x: x, y: base + wave))
            }
            path.addLine(to: CGPoint(x: w, y: 0))
            path.closeSubpath()
            context.addPath(path)
            context.fillPath()
        }

        guard let image = context.makeImage() else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        CGImageDestinationFinalize(destination)
        return output as Data
    }
}
#endif
