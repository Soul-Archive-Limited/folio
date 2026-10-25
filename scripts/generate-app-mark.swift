// Renders the Folio app mark (page glyph + ember dot, SPEC §3.10/§4.1) as PNGs for the
// launch screen and greeting. Placeholder until the final Icon Composer artwork exists.
// Usage: swift scripts/generate-app-mark.swift
import AppKit

let out = URL(fileURLWithPath: "ios/Folio/Resources/Assets.xcassets/AppMark.imageset")
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

struct Variant { let suffix: String; let page: (CGFloat, CGFloat, CGFloat); let lines: (CGFloat, CGFloat, CGFloat, CGFloat) }
let variants = [
    Variant(suffix: "light", page: (0x16, 0x16, 0x1A), lines: (0xF5, 0xF3, 0xEF, 0.35)),
    Variant(suffix: "dark", page: (0xF4, 0xF4, 0xF5), lines: (0x0A, 0x0A, 0x0C, 0.22)),
]
func cg(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor { CGColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a) }

for v in variants {
    for scale in [1, 2, 3] {
        let px = 72 * scale
        let s = CGFloat(scale)
        let c = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                          space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        c.scaleBy(x: s, y: s)
        // Page: 46 x 60 pt, centred, corner radius 9.
        let page = CGRect(x: 13, y: 6, width: 46, height: 60)
        c.setFillColor(cg(v.page.0, v.page.1, v.page.2))
        c.addPath(CGPath(roundedRect: page, cornerWidth: 9, cornerHeight: 9, transform: nil)); c.fillPath()
        c.setFillColor(cg(v.lines.0, v.lines.1, v.lines.2, v.lines.3))
        for (i, w) in [30.0, 34.0, 25.0].enumerated() {
            c.addPath(CGPath(roundedRect: CGRect(x: 21, y: 40 - Double(i) * 8, width: w, height: 3), cornerWidth: 1.5, cornerHeight: 1.5, transform: nil))
        }
        c.fillPath()
        // Ember dot overlapping the top-trailing corner.
        c.setFillColor(v.suffix == "light" ? cg(0xF0, 0x60, 0x2A) : cg(0xFF, 0x7A, 0x45))
        c.fillEllipse(in: CGRect(x: 47, y: 52, width: 16, height: 16))
        let rep = NSBitmapImageRep(cgImage: c.makeImage()!)
        let name = "AppMark-\(v.suffix)@\(scale)x.png"
        try rep.representation(using: .png, properties: [:])!.write(to: out.appending(path: name))
    }
}
let images = variants.flatMap { v in [1, 2, 3].map { s -> [String: Any] in
    var d: [String: Any] = ["filename": "AppMark-\(v.suffix)@\(s)x.png", "idiom": "universal", "scale": "\(s)x"]
    if v.suffix == "dark" { d["appearances"] = [["appearance": "luminosity", "value": "dark"]] }
    return d
} }
let json: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]).write(to: out.appending(path: "Contents.json"))
print("Wrote AppMark.imageset")
