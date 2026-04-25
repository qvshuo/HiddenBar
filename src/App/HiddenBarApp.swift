import SwiftUI

@main
struct HiddenBarApp: App {
    @NSApplicationDelegateAdaptor(MenuBarAppDelegate.self) private var appDelegate
    @State private var store = MenuBarStore.shared

    var body: some Scene {
        MenuBarExtra("Hidden Bar", systemImage: store.menuBarExtraIconName, isInserted: .constant(false)) {
            Button("Quit Hidden Bar") {
                store.send(.quitRequested)
            }
        }

        Settings {
            EmptyView()
        }
    }
}
