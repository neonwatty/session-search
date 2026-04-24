import AppKit
import SwiftUI

@MainActor
final class StatusItemController {
    private let statusItem: NSStatusItem
    private let popover: NSPopover

    init(store: SessionStore, settings: AppSettings) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        popover = NSPopover()
        popover.behavior = .transient
        let hosting = NSHostingController(rootView: PopoverView(store: store, settings: settings))
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting

        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover(_:))

        statusItem.button?.image = Self.coloredIcon()
        statusItem.button?.appearsDisabled = false
    }

    private static func coloredIcon() -> NSImage {
        let orange = NSColor(red: 0.93, green: 0.55, blue: 0.24, alpha: 1.0)
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        let symbol = NSImage(
            systemSymbolName: "text.magnifyingglass",
            accessibilityDescription: "Session Search"
        )!.withSymbolConfiguration(config)!

        let size = symbol.size
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let pw = Int(size.width * scale)
        let ph = Int(size.height * scale)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard
            let ctx = CGContext(
                data: nil, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: 0,
                space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else { return symbol }

        // Scale the CG context to match Retina
        ctx.scaleBy(x: scale, y: scale)

        let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsCtx

        let rect = NSRect(origin: .zero, size: size)

        // 1. Draw the symbol (black template with alpha)
        symbol.draw(in: rect)
        // 2. Composite the orange color through the alpha mask
        orange.setFill()
        rect.fill(using: .sourceAtop)

        NSGraphicsContext.restoreGraphicsState()

        guard let cgImage = ctx.makeImage() else { return symbol }
        let result = NSImage(cgImage: cgImage, size: size)
        result.isTemplate = false
        return result
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
