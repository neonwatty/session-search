import AppKit
import Foundation

let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let inputURL = rootURL.appendingPathComponent("docs/assets/session-search-results.png")
let outputURL = rootURL.appendingPathComponent("docs/assets/session-search-social-card.png")

guard let screenshot = NSImage(contentsOf: inputURL) else {
    fputs("Could not read \(inputURL.path)\n", stderr)
    exit(1)
}

let size = NSSize(width: 1200, height: 630)
let image = NSImage(size: size)

func color(_ hex: UInt32) -> NSColor {
    NSColor(
        red: CGFloat((hex >> 16) & 0xff) / 255,
        green: CGFloat((hex >> 8) & 0xff) / 255,
        blue: CGFloat(hex & 0xff) / 255,
        alpha: 1
    )
}

func roundedRect(_ rect: NSRect, radius: CGFloat, fill: NSColor, stroke: NSColor? = nil, lineWidth: CGFloat = 1) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    fill.setFill()
    path.fill()
    if let stroke {
        stroke.setStroke()
        path.lineWidth = lineWidth
        path.stroke()
    }
}

func drawText(_ text: String, in rect: NSRect, size: CGFloat, weight: NSFont.Weight, color: NSColor, lineHeight: CGFloat? = nil) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineBreakMode = .byWordWrapping
    if let lineHeight {
        paragraph.minimumLineHeight = lineHeight
        paragraph.maximumLineHeight = lineHeight
    }
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: paragraph,
    ]
    text.draw(in: rect, withAttributes: attributes)
}

image.lockFocus()

color(0xfbfaf7).setFill()
NSRect(origin: .zero, size: size).fill()

let ctx = NSGraphicsContext.current?.cgContext
ctx?.saveGState()
let gradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [color(0xfbfaf7).cgColor, color(0xe8edf1).cgColor] as CFArray,
    locations: [0, 1]
)
ctx?.drawLinearGradient(
    gradient!,
    start: CGPoint(x: 0, y: size.height),
    end: CGPoint(x: size.width, y: 0),
    options: []
)
ctx?.restoreGState()

let markRect = NSRect(x: 72, y: 500, width: 58, height: 58)
roundedRect(markRect, radius: 14, fill: color(0xd66b2d))
drawText("S", in: NSRect(x: 72, y: 512, width: 58, height: 34), size: 30, weight: .bold, color: .white)
drawText("Session Search", in: NSRect(x: 148, y: 514, width: 360, height: 40), size: 30, weight: .bold, color: color(0x1d2328))

drawText(
    "Full-text search for Claude Code sessions.",
    in: NSRect(x: 72, y: 306, width: 560, height: 170),
    size: 54,
    weight: .bold,
    color: color(0x1d2328),
    lineHeight: 60
)
drawText(
    "Find any past conversation by keyword, inspect the matching snippet, and resume it from the macOS menu bar.",
    in: NSRect(x: 76, y: 198, width: 520, height: 92),
    size: 24,
    weight: .regular,
    color: color(0x58636d),
    lineHeight: 32
)

roundedRect(NSRect(x: 76, y: 92, width: 232, height: 54), radius: 8, fill: color(0x1d2328))
drawText("Download for macOS", in: NSRect(x: 100, y: 108, width: 190, height: 24), size: 20, weight: .semibold, color: .white)
drawText("neonwatty.github.io/session-search", in: NSRect(x: 76, y: 48, width: 460, height: 26), size: 18, weight: .medium, color: color(0x58636d))

let panelRect = NSRect(x: 664, y: 75, width: 456, height: 480)
roundedRect(panelRect, radius: 22, fill: color(0xe8edf1), stroke: color(0xcfd7de), lineWidth: 2)

let screenshotRect = NSRect(x: 712, y: 160, width: 360, height: 310)
roundedRect(NSRect(x: 704, y: 152, width: 376, height: 326), radius: 14, fill: color(0x20272d))
screenshot.draw(in: screenshotRect, from: NSRect(origin: .zero, size: screenshot.size), operation: .sourceOver, fraction: 1)

drawText("Local-first", in: NSRect(x: 716, y: 126, width: 110, height: 28), size: 18, weight: .semibold, color: color(0x34785d))
drawText("Terminal.app  |  iTerm2  |  Ghostty", in: NSRect(x: 838, y: 126, width: 252, height: 28), size: 16, weight: .medium, color: color(0x58636d))

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(using: .png, properties: [:])
else {
    fputs("Could not encode social card PNG\n", stderr)
    exit(1)
}

try png.write(to: outputURL)
print("Wrote \(outputURL.path)")
