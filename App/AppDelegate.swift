import AppKit
#if !MAS_BUILD
import Sparkle
#endif

final class AppDelegate: NSObject, NSApplicationDelegate {
    let captureManager = CaptureManager()
    private var coordinator: RecordingCoordinator!
    private var statusBarController: StatusBarController?
    private var floatingWindowController: FloatingWindowController?
    #if !MAS_BUILD
    private var updaterController: SPUStandardUpdaterController!
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        coordinator = RecordingCoordinator(captureManager: captureManager)
        floatingWindowController = FloatingWindowController(captureManager: captureManager, coordinator: coordinator)
        statusBarController = StatusBarController(captureManager: captureManager)

        coordinator.floatingWindowController = floatingWindowController
        statusBarController?.coordinator = coordinator

        #if !MAS_BUILD
        // Direct-download (Developer ID) builds only — Mac App Store has its own
        // update mechanism and Sparkle self-updating isn't permitted there.
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        statusBarController?.updaterController = updaterController
        #endif

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
