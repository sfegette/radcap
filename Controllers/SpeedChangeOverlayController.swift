import AppKit
import SwiftUI

// MARK: - Model

private final class SpeedOverlayModel: ObservableObject {
    @Published var speedText: String = ""
}

// MARK: - View  (matches countdown style: large centered text, same shadow/font)

private struct SpeedChangeOverlayView: View {
    @ObservedObject var model: SpeedOverlayModel

    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 1.0

    var body: some View {
        ZStack {
            Color.black.opacity(0.001)  // fills window so hit-test pass-through covers the whole screen

            Text(model.speedText)
                .font(.system(size: 150, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.45), radius: 24, y: 6)
                .scaleEffect(scale)
                .opacity(opacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .onChange(of: model.speedText) { _, _ in popIn() }
    }

    private func popIn() {
        opacity = 1.0
        scale = 1.3
        withAnimation(.spring(duration: 0.3, bounce: 0.3)) { scale = 1.0 }
    }
}

// MARK: - Controller

final class SpeedChangeOverlayController {

    private var window: NSWindow?
    private let model = SpeedOverlayModel()
    private var dismissTask: DispatchWorkItem?

    // Call this each time speed changes. Reuses the window for rapid key presses
    // and resets the auto-dismiss timer so each press gets its full display time.
    func show(speed: Double) {
        if window == nil { buildWindow() }
        model.speedText = String(format: "%.1f×", speed)

        dismissTask?.cancel()
        let task = DispatchWorkItem { [weak self] in self?.dismiss() }
        dismissTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: task)
    }

    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        window?.orderOut(nil)
        window = nil
    }

    private func buildWindow() {
        guard let screen = NSScreen.main else { return }
        let win = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = .screenSaver
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        win.ignoresMouseEvents = true
        let hosting = NSHostingView(rootView: SpeedChangeOverlayView(model: model))
        hosting.sizingOptions = []
        win.contentView = hosting
        win.orderFront(nil)
        window = win
    }
}
