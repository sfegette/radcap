import AppKit
import SwiftUI

final class FloatingWindowController {
    private var panel: NSPanel?
    private let captureManager: CaptureManager

    init(captureManager: CaptureManager) {
        self.captureManager = captureManager
    }

    func toggle() {
        guard let panel else { show(); return }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.makeKeyAndOrderFront(nil)
        }
    }

    func show() {
        if panel == nil { buildPanel() }
        panel?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Panel Construction

    private func buildPanel() {
        let rootView = ContentView()
            .environmentObject(captureManager)
            .environmentObject(AppSettings.shared)

        let hosting = NSHostingController(rootView: rootView)

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 620),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        p.title = "Radcap"
        p.isFloatingPanel = true
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isMovableByWindowBackground = true
        p.contentViewController = hosting

        // Restore last position, else center
        let ox = UserDefaults.standard.double(forKey: "windowX")
        let oy = UserDefaults.standard.double(forKey: "windowY")
        if ox != 0 || oy != 0 {
            p.setFrameOrigin(NSPoint(x: ox, y: oy))
        } else {
            p.center()
        }

        // Save position on move
        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: p,
            queue: .main
        ) { [weak p] _ in
            guard let p else { return }
            UserDefaults.standard.set(p.frame.origin.x, forKey: "windowX")
            UserDefaults.standard.set(p.frame.origin.y, forKey: "windowY")
        }

        panel = p
    }
}
