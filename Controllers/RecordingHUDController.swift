import AppKit
import SwiftUI

final class RecordingHUDController {

    private let captureManager: CaptureManager
    private var pillPanel: NSPanel?
    private var scrollMonitor: Any?

    private let scrollModel   = TeleprompterScrollModel()
    private let opacityModel  = PreviewOpacityModel(defaultOpacity: AppSettings.shared.recordingPreviewOpacity)

    private let pillW: CGFloat = 720

    // Recomputed each show() so settings changes (font size, visible lines) take effect.
    private var currentPillH: CGFloat {
        TeleprompterPillView.pillHeight(
            fontSize: AppSettings.shared.teleprompterFontSize,
            visibleLines: AppSettings.shared.teleprompterVisibleLines
        )
    }

    init(captureManager: CaptureManager) {
        self.captureManager = captureManager
    }

    // MARK: - Show / Hide

    func show() {
        opacityModel.opacity = AppSettings.shared.recordingPreviewOpacity
        // Reset first so the false→true transition always triggers onChange in the view
        scrollModel.isScrolling = false

        if pillPanel == nil { pillPanel = buildPillPanel() }

        pillPanel?.orderFront(nil)
        installScrollMonitor()

        // 0.05 s lets SwiftUI finish layout before scroll begins; add any user-configured
        // pre-scroll delay on top of that.
        let delay = 0.05 + AppSettings.shared.teleprompterPreScrollDelay
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.scrollModel.isScrolling = true
        }
    }

    func hide() {
        scrollModel.isScrolling = false
        pillPanel?.orderOut(nil)
        removeScrollMonitor()
        opacityModel.opacity = AppSettings.shared.recordingPreviewOpacity
        // Nil the panel so it's rebuilt fresh on next show(), picking up any settings changes.
        pillPanel = nil
    }

    // MARK: - Panel Builder

    private func buildPillPanel() -> NSPanel {
        let pillH = currentPillH
        let (x, y) = pillOrigin(pillH: pillH)
        let panel = makeHUDPanel(frame: NSRect(x: x, y: y, width: pillW, height: pillH))
        let rootView = TeleprompterPillView()
            .environmentObject(AppSettings.shared)
            .environmentObject(captureManager)
            .environmentObject(scrollModel)
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

    private func pillOrigin(pillH: CGFloat) -> (CGFloat, CGFloat) {
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
