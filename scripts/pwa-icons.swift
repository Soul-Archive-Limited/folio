// Renders the web app's install icons (Batch J) from Folio's mark: ink tile, paper page, ember dot.
// Usage: swift scripts/pwa-icons.swift web/public/icons
import AppKit

func icon(size: CGFloat, maskable: Bool, to path: String) {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let ink = NSColor(srgbRed: 0x16 / 255, green: 0x16 / 255, blue: 0x1A / 255, alpha: 1)
    let paper = NSColor(srgbRed: 0xF5 / 255, green: 0xF3 / 255, blue: 0xEF / 255, alpha: 1)
    let ember = NSColor(srgbRed: 1, green: 0x7A / 255, blue: 0x45 / 255, alpha: 1)
    // Maskable icons are cropped to a circle or squircle: full-bleed ink, the mark inside the safe zone.
    ink.setFill()
    if maskable { NSRect(x: 0, y: 0, width: size, height: size).fill() } else {
        NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size, height: size), xRadius: size * 0.25, yRadius: size * 0.25).fill()
    }
    let unit = size / 64 * (maskable ? 0.72 : 1)
    let origin = (size - 64 * unit) / 2
    func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
        NSRect(x: origin + x * unit, y: size - origin - (y + h) * unit, width: w * unit, height: h * unit)
    }
    paper.setFill()
    NSBezierPath(roundedRect: rect(19, 16, 26, 32), xRadius: 5 * unit, yRadius: 5 * unit).fill()
    ember.setFill()
    NSBezierPath(ovalIn: rect(35.5, 16.5, 9, 9)).fill()
    image.unlockFocus()
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

let folder = CommandLine.arguments[1]
icon(size: 192, maskable: false, to: "\(folder)/icon-192.png")
icon(size: 512, maskable: false, to: "\(folder)/icon-512.png")
icon(size: 512, maskable: true, to: "\(folder)/icon-maskable-512.png")
