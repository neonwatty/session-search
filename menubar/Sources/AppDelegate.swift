import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Will wire up StatusItemController + SessionStore in later tasks
        print("SessionSearch launched")
    }
}
