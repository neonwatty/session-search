import AppKit

enum SearchKeyboardMonitor {
    static func install(
        moveSelection: @escaping (Bool) -> Void,
        openSelected: @escaping () -> Bool,
        copySelected: @escaping () -> Bool
    ) -> Any? {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 125:
                moveSelection(true)
                return nil
            case 126:
                moveSelection(false)
                return nil
            case 36:
                return openSelected() ? nil : event
            case 8:
                guard event.modifierFlags.contains(.command) else { return event }
                return copySelected() ? nil : event
            default:
                return event
            }
        }
    }

    static func remove(_ monitor: Any?) {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
