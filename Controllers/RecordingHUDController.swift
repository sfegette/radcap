import AppKit
import SwiftUI

final class RecordingHUDController {

    private let captureManager: CaptureManager
    private var pillPanel: NSPanel?
    private var previewPanel: NSPanel?
    private var scrollMonitor: Any?

    private let scrollModel   = TeleprompterScrollModel()
    private let opacityModel  = PreviewOpacityModel(defaultOpacity: AppSettings.shared.recordingPreviewOpacity)

    // Pill dimensions
    private let pillW: CGFloat    = 720
    private let pillH: CGFloat    = 120
    private let previewH: CGFloat = 210
    private let gap: CGFloat      = 4

    init(captureManager: CaptureManager) {
        self.captureManager = captureManager
    }

    // MARK: - Show / Hide

    func show() {
        opacityModel.opacity = AppSettings.shared.recordingPreviewOpacity
        // Reset first so the false→true transition always triggers onChange in the view
        scrollModel.isScrolling = false

        if pillPanel == nil    { pillPanel    = buildPillPanel() }
        if previewPanel == nil { previewPanel = buildPreviewPanel() }

        pillPanel?.orderFront(nil)
        previewPanel?.orderFront(nil)
        installScrollMonitor()

        // Delay start until after the panel is visible and SwiftUI has laid out the content;
        // starting the timer before orderFront causes scrollOffset to accumulate before the
        // first render, making the text appear mid-scroll or at the tail.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.scrollModel.isScrolling = true
        }
    }

    func hide() {
        scrollModel.isScrolling = false
        pillPanel?.orderOut(nil)
        previewPanel?.orderOut(nil)
        removeScrollMonitor()
        opacityModel.opacity = AppSettings.shared.recordingPreviewOpacity
    }

    // MARK: - Panel Builders

    private func buildPillPanel() -> NSPanel {
        let (x, y) = pillOrigin()
        let panel = makeHUDPanel(frame: NSRect(x: x, y: y, width: pillW, height: pillH))
        let rootView = TeleprompterPillView()
            .environmentObject(AppSettings.shared)
            .environmentObject(captureManager)
            .environmentObject(scrollModel)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        return panel
    }

    private func buildPreviewPanel() -> NSPanel {
        let (pillX, pillY) = pillOrigin()
        let x = pillX
        let y = pillY - previewH - gap
        let panel = makeHUDPanel(frame: NSRect(x: x, y: y, width: pillW, height: previewH))
        let rootView = RecordingPreviewView(
            session: captureManager.captureSession,
            cropMode: captureManager.cropMode
        )
        .environmentObject(opacityModel)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        return panel
    }

    private func makeHUDPanel(frame: NSRect) -> NSPanel {
        let panel = NonKeyPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        return panel
    }

    // MARK: - Positioning

    private func pillOrigin() -> (CGFloat, CGFloat) {
        guard let screen = NSScreen.main else { return (0, 0) }
        let x = (screen.frame.width - pillW) / 2
        let y = screen.visibleFrame.maxY - pillH - 4
        return (x, y)
    }

    // MARK: - Scroll Monitor (preview opacity)

    private func installScrollMonitor() {
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self else { return event }
            let delta = Double(event.scrollingDeltaY)
            let newOpacity = min(1.0, max(0.15, self.opacityModel.opacity - delta * 0.02))
            DispatchQueue.main.async { self.opacityModel.opacity = newOpacity }
            return event
        }
    }

    private func removeScrollMonitor() {
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }
    }
}

// NSPanel subclass that refuses key/main status so the HUD never steals focus
private final class NonKeyPanel: NSPanel {
    override var canBecomeKey: Bool  { false }
    override var canBecomeMain: Bool { false }
}
