import AppKit
import SwiftUI

final class FloatingWindowController {
    private var panel: GlassPanel?
    private let captureManager: CaptureManager
    private let coordinator: RecordingCoordinator

    init(captureManager: CaptureManager, coordinator: RecordingCoordinator) {
        self.captureManager = captureManager
        self.coordinator    = coordinator
    }

    func toggle() {
        guard let panel else { show(); return }
        panel.isVisible ? hide() : show()
    }

    func show() {
        if panel == nil { buildPanel() }
        captureManager.setWindowVisible(true)
        panel?.makeKeyAndOrderFront(nil)
    }

    // stopCamera: false during recording flow so the session stays live through the countdown
    func hide(stopCamera: Bool = true) {
        panel?.orderOut(nil)
        if stopCamera { captureManager.setWindowVisible(false) }
    }

    // MARK: - Panel Construction

    private func buildPanel() {
        let rootView = ContentView(onClose: { [weak self] in self?.hide() })
            .environmentObject(captureManager)
            .environmentObject(AppSettings.shared)
            .environmentObject(coordinator)

        let hosting = NSHostingController(rootView: rootView)

        let p = GlassPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 620),
            styleMask: [.borderless, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.isMovableByWindowBackground = true
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.contentViewController = hosting

        let ox = UserDefaults.standard.double(forKey: "windowX")
        let oy = UserDefaults.standard.double(forKey: "windowY")
        if ox != 0 || oy != 0 {
            p.setFrameOrigin(NSPoint(x: ox, y: oy))
        } else {
            p.center()
        }

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

// Borderless panel that can still receive keyboard events
private final class GlassPanel: NSPanel {
    override var canBecomeKey: Bool  { true }
    override var canBecomeMain: Bool { false }
}
