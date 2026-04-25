import SwiftUI

@main
struct HiddenBarApp: App {
    @NSApplicationDelegateAdaptor(MenuBarAppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Hidden Bar", systemImage: "circle.fill", isInserted: .constant(false)) {
            // The actual menu bar UI is hosted by AppKit; this hidden scene keeps the SwiftUI app lifecycle.
            EmptyView()
        }
    }
}
