import AppKit

@MainActor
final class MenuBarAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MenuBarStore.shared.bootstrapIfNeeded()
    }
}
