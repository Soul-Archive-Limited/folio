// Folio's custom icon set (Batch K): one drawing per icon, outlined at three weights into SF Symbol
// templates (Ultralight-S / Regular-S / Black-S, interpolated by the system for every weight and
// scale) for iOS, and into 24-px SVG paths for the web app and website.
// Usage: swift scripts/brand/symbols.swift   (from the repo root)
import AppKit
import CoreGraphics

// MARK: Drawing language — a 100-unit design square, y down. Strokes have round caps and joins.

enum Piece {
    case stroke(CGPath)       // outlined at the master's stroke width
    case fill(CGPath)         // filled, and grown by half the stroke width so it keeps pace with the weight
    case dot(CGPoint, CGFloat) // a filled dot whose radius grows with the weight
    case polyline([CGPoint])   // a smooth open curve, outlined by hand so every weight has the same points
}

struct Icon {
    let name: String
    var width: CGFloat = 100
    let pieces: [Piece]
}

func path(_ build: (CGMutablePath) -> Void) -> CGPath { let p = CGMutablePath(); build(p); return p }
func line(_ pts: [(CGFloat, CGFloat)], closed: Bool = false) -> Piece {
    .stroke(path { p in
        p.move(to: CGPoint(x: pts[0].0, y: pts[0].1))
        for q in pts.dropFirst() { p.addLine(to: CGPoint(x: q.0, y: q.1)) }
        if closed { p.closeSubpath() }
    })
}
func rrect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> Piece {
    .stroke(CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: r, cornerHeight: r, transform: nil))
}
func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> Piece {
    .stroke(CGPath(ellipseIn: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r), transform: nil))
}
func arc(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ from: CGFloat, _ to: CGFloat, clockwise: Bool = false) -> Piece {
    .stroke(path { $0.addArc(center: CGPoint(x: cx, y: cy), radius: r, startAngle: from * .pi / 180, endAngle: to * .pi / 180, clockwise: clockwise) })
}
func curve(_ build: (CGMutablePath) -> Void) -> Piece { .stroke(path(build)) }
/// A curve flattened to fixed segments: CoreGraphics outlines Béziers adaptively, so a curve
/// stroked at three weights comes out with different point counts and can't interpolate.
func smooth(segments: Int = 16, _ build: (CGMutablePath) -> Void) -> Piece {
    var points: [CGPoint] = []
    path(build).applyWithBlock { e in
        let p = e.pointee.points
        switch e.pointee.type {
        case .moveToPoint, .addLineToPoint: points.append(p[0])
        case .addCurveToPoint:
            let (p0, p1, p2, p3) = (points.last!, p[0], p[1], p[2])
            for i in 1...segments {
                let t = CGFloat(i) / CGFloat(segments), u = 1 - t
                let a = u * u * u, b = 3 * u * u * t, c = 3 * u * t * t, d = t * t * t
                points.append(CGPoint(x: a * p0.x + b * p1.x + c * p2.x + d * p3.x, y: a * p0.y + b * p1.y + c * p2.y + d * p3.y))
            }
        default: break
        }
    }
    return .polyline(points)
}

/// Outlines an open polyline: both sides offset along averaged normals, round caps of fixed
/// segment count. The same points at every width (CoreGraphics adds joins by angle and width).
func strokeByHand(_ pts: [CGPoint], width w: CGFloat) -> CGPath {
    func normal(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        let dx = b.x - a.x, dy = b.y - a.y, l = max(hypot(dx, dy), 0.0001)
        return CGPoint(x: -dy / l, y: dx / l)
    }
    var normals: [CGPoint] = []
    for i in pts.indices {
        let n1 = i > 0 ? normal(pts[i - 1], pts[i]) : normal(pts[i], pts[i + 1])
        let n2 = i < pts.count - 1 ? normal(pts[i], pts[i + 1]) : n1
        let m = CGPoint(x: n1.x + n2.x, y: n1.y + n2.y), l = max(hypot(m.x, m.y), 0.0001)
        let cos = (m.x * n1.x + m.y * n1.y) / l
        normals.append(CGPoint(x: m.x / l / max(cos, 0.5), y: m.y / l / max(cos, 0.5)))
    }
    let h = w / 2, out = CGMutablePath()
    out.move(to: CGPoint(x: pts[0].x + normals[0].x * h, y: pts[0].y + normals[0].y * h))
    for i in pts.indices.dropFirst() { out.addLine(to: CGPoint(x: pts[i].x + normals[i].x * h, y: pts[i].y + normals[i].y * h)) }
    func cap(_ c: CGPoint, from n: CGPoint) {
        let start = atan2(n.y, n.x)
        for k in 1...8 { let a = start - CGFloat(k) * .pi / 8; out.addLine(to: CGPoint(x: c.x + cos(a) * h, y: c.y + sin(a) * h)) }
    }
    cap(pts.last!, from: normals.last!)
    for i in pts.indices.reversed().dropFirst() { out.addLine(to: CGPoint(x: pts[i].x - normals[i].x * h, y: pts[i].y - normals[i].y * h)) }
    cap(pts[0], from: CGPoint(x: -normals[0].x, y: -normals[0].y))
    out.closeSubpath()
    return out
}

func dot(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> Piece { .dot(CGPoint(x: x, y: y), r) }

/// The nib from Folio's mark, tip at (x, y), pointing down, `h` tall.
func nib(_ x: CGFloat, _ y: CGFloat, _ h: CGFloat) -> Piece {
    let s = h / 58
    return .fill(path { p in
        func pt(_ a: CGFloat, _ b: CGFloat) -> CGPoint { CGPoint(x: x + a * s, y: y + b * s) }
        p.move(to: pt(0, 0)); p.addLine(to: pt(-12, -30))
        p.addCurve(to: pt(-9, -44), control1: pt(-13, -35), control2: pt(-12, -40))
        p.addLine(to: pt(-9, -53)); p.addQuadCurve(to: pt(-4, -58), control: pt(-9, -58))
        p.addLine(to: pt(4, -58)); p.addQuadCurve(to: pt(9, -53), control: pt(9, -58))
        p.addLine(to: pt(9, -44)); p.addCurve(to: pt(12, -30), control1: pt(12, -40), control2: pt(13, -35))
        p.closeSubpath()
    })
}

// MARK: The set

let icons: [Icon] = [
    // Tabs
    Icon(name: "folio.calendar", pieces: [
        rrect(8, 16, 84, 76, 16), line([(8, 38), (92, 38)]), line([(32, 6), (32, 24)]), line([(68, 6), (68, 24)]),
        dot(68, 66, 7),
    ]),
    Icon(name: "folio.journal", width: 104, pieces: [
        smooth { p in p.move(to: CGPoint(x: 46, y: 22)); p.addCurve(to: CGPoint(x: 6, y: 18), control1: CGPoint(x: 34, y: 14), control2: CGPoint(x: 18, y: 14))
            p.addLine(to: CGPoint(x: 6, y: 80)); p.addCurve(to: CGPoint(x: 44, y: 88), control1: CGPoint(x: 20, y: 78), control2: CGPoint(x: 34, y: 80)) },
        smooth { p in p.move(to: CGPoint(x: 58, y: 22)); p.addCurve(to: CGPoint(x: 98, y: 18), control1: CGPoint(x: 70, y: 14), control2: CGPoint(x: 86, y: 14))
            p.addLine(to: CGPoint(x: 98, y: 80)); p.addCurve(to: CGPoint(x: 60, y: 88), control1: CGPoint(x: 84, y: 78), control2: CGPoint(x: 70, y: 80)) },
        nib(52, 82, 52),
    ]),
    Icon(name: "folio.todo", pieces: [
        rrect(6, 10, 30, 30, 9), line([(13, 25), (19, 32), (30, 17)]), line([(50, 25), (94, 25)]),
        rrect(6, 58, 30, 30, 9), line([(50, 73), (82, 73)]),
    ]),
    Icon(name: "folio.profile", pieces: [
        circle(50, 50, 42), circle(50, 40, 14),
        curve { p in p.move(to: CGPoint(x: 23, y: 80)); p.addCurve(to: CGPoint(x: 77, y: 80), control1: CGPoint(x: 30, y: 60), control2: CGPoint(x: 70, y: 60)) },
    ]),
    // Actions
    Icon(name: "folio.plus", pieces: [line([(50, 12), (50, 88)]), line([(12, 50), (88, 50)])]),
    Icon(name: "folio.dictate", width: 84, pieces: [
        rrect(28, 6, 28, 52, 14), smooth { p in p.move(to: CGPoint(x: 12, y: 44)); p.addCurve(to: CGPoint(x: 72, y: 44), control1: CGPoint(x: 12, y: 82), control2: CGPoint(x: 72, y: 82)) },
        line([(42, 74), (42, 92)]),
    ]),
    Icon(name: "folio.sparkle", pieces: [
        .fill(path { p in
            p.move(to: CGPoint(x: 42, y: 14))
            p.addQuadCurve(to: CGPoint(x: 70, y: 52), control: CGPoint(x: 46, y: 48)); p.addQuadCurve(to: CGPoint(x: 42, y: 90), control: CGPoint(x: 46, y: 56))
            p.addQuadCurve(to: CGPoint(x: 14, y: 52), control: CGPoint(x: 38, y: 56)); p.addQuadCurve(to: CGPoint(x: 42, y: 14), control: CGPoint(x: 38, y: 48))
            p.closeSubpath()
        }),
        .fill(path { p in
            p.move(to: CGPoint(x: 78, y: 8))
            p.addQuadCurve(to: CGPoint(x: 92, y: 24), control: CGPoint(x: 80, y: 22)); p.addQuadCurve(to: CGPoint(x: 78, y: 40), control: CGPoint(x: 80, y: 26))
            p.addQuadCurve(to: CGPoint(x: 64, y: 24), control: CGPoint(x: 76, y: 26)); p.addQuadCurve(to: CGPoint(x: 78, y: 8), control: CGPoint(x: 76, y: 22))
            p.closeSubpath()
        }),
    ]),
    Icon(name: "folio.photo", pieces: [
        rrect(6, 16, 88, 70, 14), line([(8, 74), (36, 48), (56, 66), (68, 56), (92, 76)]), dot(68, 36, 7),
    ]),
    Icon(name: "folio.camera", pieces: [
        curve { p in
            p.move(to: CGPoint(x: 20, y: 28)); p.addLine(to: CGPoint(x: 30, y: 28)); p.addLine(to: CGPoint(x: 38, y: 16)); p.addLine(to: CGPoint(x: 62, y: 16))
            p.addLine(to: CGPoint(x: 70, y: 28)); p.addLine(to: CGPoint(x: 80, y: 28))
            p.addArc(tangent1End: CGPoint(x: 94, y: 28), tangent2End: CGPoint(x: 94, y: 42), radius: 14)
            p.addLine(to: CGPoint(x: 94, y: 72)); p.addArc(tangent1End: CGPoint(x: 94, y: 86), tangent2End: CGPoint(x: 80, y: 86), radius: 14)
            p.addLine(to: CGPoint(x: 20, y: 86)); p.addArc(tangent1End: CGPoint(x: 6, y: 86), tangent2End: CGPoint(x: 6, y: 72), radius: 14)
            p.addLine(to: CGPoint(x: 6, y: 42)); p.addArc(tangent1End: CGPoint(x: 6, y: 28), tangent2End: CGPoint(x: 20, y: 28), radius: 14)
            p.closeSubpath()
        },
        circle(50, 56, 16),
    ]),
    Icon(name: "folio.scan", pieces: [
        line([(8, 30), (8, 8), (30, 8)]), line([(70, 8), (92, 8), (92, 30)]), line([(92, 70), (92, 92), (70, 92)]), line([(30, 92), (8, 92), (8, 70)]),
        line([(30, 38), (70, 38)]), line([(30, 52), (70, 52)]), line([(30, 66), (56, 66)]),
    ]),
    Icon(name: "folio.category", pieces: [
        curve { p in
            p.move(to: CGPoint(x: 48, y: 10)); p.addLine(to: CGPoint(x: 84, y: 10))
            p.addArc(tangent1End: CGPoint(x: 90, y: 10), tangent2End: CGPoint(x: 90, y: 16), radius: 6)
            p.addLine(to: CGPoint(x: 90, y: 50)); p.addLine(to: CGPoint(x: 50, y: 90)); p.addLine(to: CGPoint(x: 10, y: 50))
            p.closeSubpath()
        },
        dot(70, 30, 6),
    ]),
    Icon(name: "folio.mood", pieces: [
        circle(50, 50, 40),
        .fill(path { p in p.addArc(center: CGPoint(x: 50, y: 50), radius: 30, startAngle: 0, endAngle: .pi, clockwise: false); p.closeSubpath() }),
    ]),
    Icon(name: "folio.search", pieces: [circle(42, 42, 30), line([(64, 64), (90, 90)])]),
    Icon(name: "folio.lock", width: 84, pieces: [
        curve { p in p.move(to: CGPoint(x: 22, y: 42)); p.addLine(to: CGPoint(x: 22, y: 30)); p.addArc(center: CGPoint(x: 42, y: 30), radius: 20, startAngle: .pi, endAngle: 0, clockwise: false); p.addLine(to: CGPoint(x: 62, y: 42)) },
        rrect(8, 42, 68, 50, 14), dot(42, 66, 6),
    ]),
    Icon(name: "folio.share", width: 88, pieces: [
        line([(28, 40), (14, 40), (14, 92), (74, 92), (74, 40), (60, 40)]), line([(44, 62), (44, 8)]), line([(28, 22), (44, 6), (60, 22)]),
    ]),
    Icon(name: "folio.trash", width: 92, pieces: [
        line([(8, 22), (84, 22)]), line([(32, 22), (34, 10), (58, 10), (60, 22)]),
        line([(16, 22), (22, 92), (70, 92), (76, 22)]), line([(38, 40), (39, 74)]), line([(54, 40), (53, 74)]),
    ]),
    // Widget quick actions and Profile rows
    Icon(name: "folio.page.new", width: 92, pieces: [
        line([(56, 8), (14, 8), (14, 92), (74, 92), (74, 52)]),
        line([(34, 70), (40, 52), (78, 14), (88, 24), (50, 62), (34, 70)], closed: true),
    ]),
    Icon(name: "folio.task.add", pieces: [
        rrect(8, 8, 84, 84, 22), line([(28, 50), (43, 65), (72, 36)]),
    ]),
    Icon(name: "folio.appearance", pieces: [
        circle(50, 50, 40), .fill(path { p in p.addArc(center: CGPoint(x: 50, y: 50), radius: 30, startAngle: -.pi / 2, endAngle: .pi / 2, clockwise: false); p.closeSubpath() }),
    ]),
    Icon(name: "folio.sync", pieces: [
        arc(50, 50, 36, 200, 340), line([(76, 18), (84, 38), (64, 42)]),
        arc(50, 50, 36, 20, 160), line([(24, 82), (16, 62), (36, 58)]),
    ]),
    Icon(name: "folio.export", pieces: [
        line([(10, 56), (10, 90), (90, 90), (90, 56)]), line([(50, 8), (50, 62)]), line([(30, 44), (50, 64), (70, 44)]),
    ]),
    Icon(name: "folio.widgets", pieces: [
        rrect(8, 8, 36, 36, 10), rrect(56, 8, 36, 36, 10), rrect(8, 56, 36, 36, 10), rrect(56, 56, 36, 36, 10),
    ]),
    Icon(name: "folio.memories", pieces: [
        arc(52, 52, 38, 160, 520), line([(8, 30), (14, 46), (30, 40)]), line([(52, 30), (52, 54), (68, 64)]),
    ]),
    Icon(name: "folio.devices", width: 110, pieces: [
        rrect(6, 14, 70, 50, 10), line([(28, 82), (54, 82)]), line([(41, 64), (41, 82)]), rrect(80, 34, 24, 52, 8),
    ]),
    // Batch N: places on entries and the Journal's Places map
    Icon(name: "folio.place", width: 84, pieces: [
        // One open polyline from the tip round the head and back (fixed points at every weight).
        smooth(segments: 12) { p in
            p.move(to: CGPoint(x: 42, y: 92)); p.addCurve(to: CGPoint(x: 10, y: 40), control1: CGPoint(x: 28, y: 76), control2: CGPoint(x: 10, y: 60))
            p.addCurve(to: CGPoint(x: 42, y: 8), control1: CGPoint(x: 10, y: 22.33), control2: CGPoint(x: 24.33, y: 8))
            p.addCurve(to: CGPoint(x: 74, y: 40), control1: CGPoint(x: 59.67, y: 8), control2: CGPoint(x: 74, y: 22.33))
            p.addCurve(to: CGPoint(x: 42, y: 92), control1: CGPoint(x: 74, y: 60), control2: CGPoint(x: 56, y: 76))
        },
        dot(42, 40, 9),
    ]),
    Icon(name: "folio.map", pieces: [
        line([(8, 20), (36, 8), (64, 20), (92, 8), (92, 80), (64, 92), (36, 80), (8, 92)], closed: true),
        line([(36, 8), (36, 80)]), line([(64, 20), (64, 92)]),
    ]),
    Icon(name: "folio.invite", width: 108, pieces: [
        circle(40, 34, 18),
        curve { p in p.move(to: CGPoint(x: 8, y: 90)); p.addCurve(to: CGPoint(x: 72, y: 90), control1: CGPoint(x: 12, y: 58), control2: CGPoint(x: 68, y: 58)) },
        line([(88, 30), (88, 66)]), line([(70, 48), (106, 48)]),
    ]),
]

// MARK: Outlining

struct Master { let name: String; let width: CGFloat }
let masters = [Master(name: "Ultralight-S", width: 3), Master(name: "Regular-S", width: 9), Master(name: "Black-S", width: 13)]

func outline(_ icon: Icon, stroke w: CGFloat) -> CGPath {
    var shapes: [CGPath] = []
    for piece in icon.pieces {
        switch piece {
        case .stroke(let p): shapes.append(p.copy(strokingWithWidth: w, lineCap: .round, lineJoin: .round, miterLimit: 4))
        case .fill(let p):
            // Grown by scaling about its centre (a stroke would add points that vary with the width).
            let box = p.boundingBoxOfPath, k = 1 + w * 0.5 / max(box.width, box.height)
            var t = CGAffineTransform(translationX: box.midX, y: box.midY).scaledBy(x: k, y: k).translatedBy(x: -box.midX, y: -box.midY)
            shapes.append(p.copy(using: &t) ?? p)
        case .polyline(let pts): shapes.append(strokeByHand(pts, width: w))
        case .dot(let c, let r):
            let rr = r + w * 0.35
            shapes.append(CGPath(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr, width: 2 * rr, height: 2 * rr), transform: nil))
        }
    }
    // Appended, not unioned: a union's structure changes with the stroke width, and the three
    // masters must match point for point to interpolate. Overlaps fill under the non-zero rule.
    let all = CGMutablePath()
    for shape in shapes { all.addPath(shape) }
    return all
}

func svgPath(_ p: CGPath, transform t: CGAffineTransform) -> String {
    var out: [String] = []
    func f(_ v: CGFloat) -> String { String(format: "%.3f", v).replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression) }
    func pt(_ q: CGPoint) -> String { let r = q.applying(t); return "\(f(r.x)) \(f(r.y))" }
    p.applyWithBlock { e in
        let pts = e.pointee.points
        switch e.pointee.type {
        case .moveToPoint: out.append("M\(pt(pts[0]))")
        case .addLineToPoint: out.append("L\(pt(pts[0]))")
        case .addQuadCurveToPoint: out.append("Q\(pt(pts[0])) \(pt(pts[1]))")
        case .addCurveToPoint: out.append("C\(pt(pts[0])) \(pt(pts[1])) \(pt(pts[2]))")
        case .closeSubpath: out.append("Z")
        @unknown default: break
        }
    }
    return out.joined(separator: " ")
}

func signature(_ p: CGPath) -> [Int32] {
    var s: [Int32] = []
    p.applyWithBlock { s.append($0.pointee.type.rawValue) }
    return s
}

// Symbol space: the design square becomes 80 units, from 75 above the baseline to 5 below
// (cap height is 70.459 at the template's 100 pt), so icons centre on capitals like SF Symbols.
let scale: CGFloat = 0.8
func symbolTransform(margin: CGFloat) -> CGAffineTransform {
    CGAffineTransform(translationX: margin, y: -75).scaledBy(x: scale, y: scale)
}

func template(_ icon: Icon) -> (svg: String, compatible: Bool) {
    let columns: [String: CGFloat] = ["Ultralight-S": 559, "Regular-S": 1391, "Black-S": 2853]
    var guides: [String] = [], symbols: [String] = [], signatures: [[Int32]] = []
    for m in masters {
        let outlined = outline(icon, stroke: m.width)
        signatures.append(signature(outlined))
        let margin: CGFloat = 4 + m.width * 0.3
        let w = icon.width * scale + 2 * margin
        let x = columns[m.name]! - w / 2
        guides.append(#"<line id="left-margin-\#(m.name)" style="fill:none;stroke:#00AEEF;stroke-width:0.5;opacity:1.0;" x1="\#(x)" x2="\#(x)" y1="600.785" y2="720.121"/>"#)
        guides.append(#"<line id="right-margin-\#(m.name)" style="fill:none;stroke:#00AEEF;stroke-width:0.5;opacity:1.0;" x1="\#(x + w)" x2="\#(x + w)" y1="600.785" y2="720.121"/>"#)
        symbols.append(#"<g id="\#(m.name)" transform="matrix(1 0 0 1 \#(x) 696)"><path class="monochrome-0 multicolor-0:tintColor hierarchical-0:primary SFSymbolsPreviewWireframe" d="\#(svgPath(outlined, transform: symbolTransform(margin: margin)))"/></g>"#)
    }
    let svg = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
    <!-- Generated by scripts/brand/symbols.swift (Batch K). Do not edit. -->
    <svg version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="3300" height="2200">
    <g id="Notes">
    <rect height="2200" id="artboard" style="fill:white;opacity:1" width="3300" x="0" y="0"/>
    <text id="template-version" style="stroke:none;fill:black;font-family:sans-serif;font-size:13;" transform="matrix(1 0 0 1 2952 1933)">Template v.3.0</text>
    <text id="descriptive-name" style="stroke:none;fill:black;font-family:sans-serif;font-size:13;" transform="matrix(1 0 0 1 263 1933)">\(icon.name)</text>
    </g>
    <g id="Guides">
    <line id="Baseline-S" style="fill:none;stroke:#27AAE1;opacity:1;stroke-width:0.5;" x1="263" x2="3036" y1="696" y2="696"/>
    <line id="Capline-S" style="fill:none;stroke:#27AAE1;opacity:1;stroke-width:0.5;" x1="263" x2="3036" y1="625.541" y2="625.541"/>
    <line id="Baseline-M" style="fill:none;stroke:#27AAE1;opacity:1;stroke-width:0.5;" x1="263" x2="3036" y1="1126" y2="1126"/>
    <line id="Capline-M" style="fill:none;stroke:#27AAE1;opacity:1;stroke-width:0.5;" x1="263" x2="3036" y1="1055.54" y2="1055.54"/>
    <line id="Baseline-L" style="fill:none;stroke:#27AAE1;opacity:1;stroke-width:0.5;" x1="263" x2="3036" y1="1556" y2="1556"/>
    <line id="Capline-L" style="fill:none;stroke:#27AAE1;opacity:1;stroke-width:0.5;" x1="263" x2="3036" y1="1485.54" y2="1485.54"/>
    \(guides.joined(separator: "\n"))
    </g>
    <g id="Symbols">
    \(symbols.joined(separator: "\n"))
    </g>
    </svg>

    """
    return (svg, Set(signatures.map { $0.description }).count == 1)
}

// MARK: Output

let fm = FileManager.default
// The app's catalog, and the widget extension's own (widgets, controls and quick actions).
let catalogs = ["ios/Folio/Resources/Assets.xcassets/Symbols", "ios/FolioWidgets/Assets.xcassets/Symbols"].map { URL(fileURLWithPath: $0) }
for catalog in catalogs {
    try? fm.removeItem(at: catalog)
    try! fm.createDirectory(at: catalog, withIntermediateDirectories: true)
    try! #"{"info":{"author":"xcode","version":1},"properties":{"provides-namespace":false}}"#.write(to: catalog.appending(path: "Contents.json"), atomically: true, encoding: .utf8)
}
let widgetRoot = URL(fileURLWithPath: "ios/FolioWidgets/Assets.xcassets/Contents.json")
try! #"{"info":{"author":"xcode","version":1}}"#.write(to: widgetRoot, atomically: true, encoding: .utf8)

var webIcons: [String] = []
var incompatible: [String] = []
for icon in icons {
    let (svg, compatible) = template(icon)
    if !compatible { incompatible.append(icon.name) }
    for catalog in catalogs {
        let set = catalog.appending(path: "\(icon.name).symbolset")
        try! fm.createDirectory(at: set, withIntermediateDirectories: true)
        try! svg.write(to: set.appending(path: "\(icon.name).svg"), atomically: true, encoding: .utf8)
        try! #"{"info":{"author":"xcode","version":1},"symbols":[{"filename":"\#(icon.name).svg","idiom":"universal"}]}"#
            .write(to: set.appending(path: "Contents.json"), atomically: true, encoding: .utf8)
    }
    // Web: the Regular outline, centred in a 24 × 24 box.
    let regular = outline(icon, stroke: 9)
    let s: CGFloat = 24 / 112
    let t = CGAffineTransform(translationX: (24 - icon.width * s) / 2, y: 12 - 50 * s).scaledBy(x: s, y: s)
    let key = icon.name.replacingOccurrences(of: "folio.", with: "")
    webIcons.append("  '\(key)': '\(svgPath(regular, transform: t))',")
}
let ts = """
// Generated by scripts/brand/symbols.swift — Folio's icon set (Batch K), the same drawings as the
// iPhone's custom symbols. Each is one filled path in a 24 × 24 box. Do not edit.
export const FOLIO_ICONS = {
\(webIcons.joined(separator: "\n"))
} as const;

export type FolioIconName = keyof typeof FOLIO_ICONS;

"""
try! ts.write(to: URL(fileURLWithPath: "web/src/icons/folio-icons.ts"), atomically: true, encoding: .utf8)
print("\(icons.count) symbols written.")
if !incompatible.isEmpty { print("Masters differ in structure (no interpolation): \(incompatible.joined(separator: ", "))") }
