import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let captureManager = CaptureManager()
    private var coordinator: RecordingCoordinator!
    private var statusBarController: StatusBarController?
    private var floatingWindowController: FloatingWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        coordinator = RecordingCoordinator(captureManager: captureManager)
        floatingWindowController = FloatingWindowController(captureManager: captureManager, coordinator: coordinator)
        statusBarController = StatusBarController(captureManager: captureManager)

        coordinator.floatingWindowController = floatingWindowController
        statusBarController?.coordinator = coordinator

        statusBarController?.onToggleWindow = { [weak self] in
            self?.floatingWindowController?.toggle()
        }

        floatingWindowController?.show()

        GlobalHotkeyManager.shared.action = { [weak self] in
            guard let self else { return }
            if self.captureManager.isRecording {
                self.coordinator.stopFlow()
            } else {
                self.coordinator.startFlow()
            }
        }
        GlobalHotkeyManager.shared.register()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        captureManager.stopRecording()
        GlobalHotkeyManager.shared.unregister()
    }
}
