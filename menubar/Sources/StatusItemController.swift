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

        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        let image = NSImage(
            systemSymbolName: "text.magnifyingglass",
            accessibilityDescription: "Session Search"
        )?.withSymbolConfiguration(config)
        statusItem.button?.image = image
        statusItem.button?.contentTintColor = NSColor(red: 0.35, green: 0.78, blue: 0.98, alpha: 1.0)
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
