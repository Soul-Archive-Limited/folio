// Tiles screenshots into one labelled contact sheet.
// Usage: swift scripts/contact-sheet.swift <output.png> <columns> <title> <image>...
import AppKit

let args = CommandLine.arguments
guard args.count > 4, let columns = Int(args[2]) else { fatalError("usage: out.png columns title images...") }
let output = args[1], title = args[3], files = Array(args.dropFirst(4))
let images = files.compactMap { path in NSImage(contentsOfFile: path).map { (path, $0) } }
let tileWidth = 300.0, tileHeight = tileWidth * 2622 / 1206, gap = 24.0, labelHeight = 34.0, header = 90.0
let rows = Int((Double(images.count) / Double(columns)).rounded(.up))
let size = NSSize(width: gap + Double(columns) * (tileWidth + gap),
                  height: header + Double(rows) * (tileHeight + labelHeight + gap) + gap)
let canvas = NSImage(size: size)
canvas.lockFocus()
NSColor(srgbRed: 0.96, green: 0.95, blue: 0.94, alpha: 1).setFill()
NSRect(origin: .zero, size: size).fill()
let titleAttributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 34, weight: .bold), .foregroundColor: NSColor.black]
title.draw(at: NSPoint(x: gap, y: size.height - header + 24), withAttributes: titleAttributes)
let labelAttributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 14, weight: .medium), .foregroundColor: NSColor.darkGray]
for (index, (path, image)) in images.enumerated() {
    let column = index % columns, row = index / columns
    let x = gap + Double(column) * (tileWidth + gap)
    let y = size.height - header - Double(row + 1) * (tileHeight + labelHeight + gap) + labelHeight
    let rect = NSRect(x: x, y: y, width: tileWidth, height: tileHeight)
    NSGraphicsContext.current?.saveGraphicsState()
    NSBezierPath(roundedRect: rect, xRadius: 18, yRadius: 18).addClip()
    image.draw(in: rect)
    NSGraphicsContext.current?.restoreGraphicsState()
    let name = (URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent)
    name.draw(at: NSPoint(x: x + 4, y: y - labelHeight + 8), withAttributes: labelAttributes)
}
canvas.unlockFocus()
let rep = NSBitmapImageRep(data: canvas.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
print("Wrote \(output) (\(images.count) screenshots)")
