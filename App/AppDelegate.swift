import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let captureManager = CaptureManager()
    private var statusBarController: StatusBarController?
    private var floatingWindowController: FloatingWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as a background/accessory app — no Dock icon
        NSApp.setActivationPolicy(.accessory)

        floatingWindowController = FloatingWindowController(captureManager: captureManager)
        statusBarController = StatusBarController(captureManager: captureManager)

        statusBarController?.onToggleWindow = { [weak self] in
            self?.floatingWindowController?.toggle()
        }

        // Show window at launch
        floatingWindowController?.show()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false // keep alive as a menubar app
    }

    func applicationWillTerminate(_ notification: Notification) {
        captureManager.stopRecording()
    }
}
