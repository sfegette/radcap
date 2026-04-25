import SwiftUI

@main
struct RadcapApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Settings scene required so SwiftUI doesn't add a default "Preferences" menu item
        // pointing nowhere. Actual settings are in the floating window sheet.
        Settings {
            EmptyView()
        }
    }
}
