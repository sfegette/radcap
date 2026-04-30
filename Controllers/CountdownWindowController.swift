import AppKit
import SwiftUI

final class CountdownWindowController {
    private var window: NSWindow?

    func show(from count: Int = 3, completion: @escaping () -> Void) {
        guard let screen = NSScreen.main else {
            completion()
            return
        }

        let win = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = .statusBar
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        win.ignoresMouseEvents = true

        let rootView = CountdownOverlayView(startCount: count) { [weak self] in
            self?.dismiss()
            completion()
        }
        win.contentView = NSHostingView(rootView: rootView)
        win.orderFront(nil)
        window = win
    }

    func dismiss() {
        window?.orderOut(nil)
        window = nil
    }
}
