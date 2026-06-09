import AppKit
import Combine

final class StatusBarController {
    private let statusItem: NSStatusItem
    private var cancellables = Set<AnyCancellable>()
    private var blinkTimer: Timer?
    private var blinkOn = true

    var onToggleWindow: (() -> Void)?
    weak var coordinator: RecordingCoordinator?

    init(captureManager: CaptureManager) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setupButton()
        setIcon(recording: false, blink: true)
        observeRecording(captureManager)
    }

    deinit {
        blinkTimer?.invalidate()
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    // MARK: - Setup

    private func setupButton() {
        guard let button = statusItem.button else { return }
        button.action = #selector(handleClick(_:))
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "Open Radcap"
        button.setAccessibilityLabel("Radcap menu bar item")
        button.setAccessibilityValue("Idle")
    }

    private func observeRecording(_ captureManager: CaptureManager) {
        captureManager.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] recording in self?.updateForRecording(recording) }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            onToggleWindow?()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        if coordinator?.captureManager.isRecording == true {
            let stopItem = NSMenuItem(title: "■ Stop Recording", action: #selector(stopRecording), keyEquivalent: "")
            stopItem.target = self
            menu.addItem(stopItem)
            menu.addItem(.separator())
        }

        let windowItem = NSMenuItem(title: "Show / Hide Window", action: #selector(toggleWindow), keyEquivalent: "")
        windowItem.target = self
        menu.addItem(windowItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Radcap", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func toggleWindow()  { onToggleWindow?() }
    @objc private func stopRecording() { coordinator?.stopFlow() }

    // MARK: - Icon

    private func updateForRecording(_ isRecording: Bool) {
        blinkTimer?.invalidate()
        blinkTimer = nil
        updateAccessibility(recording: isRecording)

        if isRecording {
            blinkOn = true
            setIcon(recording: true, blink: true)
            blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
                guard let self else { return }
                blinkOn.toggle()
                setIcon(recording: true, blink: blinkOn)
            }
        } else {
            setIcon(recording: false, blink: true)
        }
    }

    private func setIcon(recording: Bool, blink: Bool) {
        guard let button = statusItem.button else { return }

        guard let image = NSImage(named: "MenubarIcon") else { return }
        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        button.image = image

        // Tint red while recording; blink by toggling between red and system tint.
        button.contentTintColor = (recording && blink) ? .systemRed : nil
    }

    private func updateAccessibility(recording: Bool) {
        guard let button = statusItem.button else { return }
        button.toolTip = recording ? "Radcap is recording. Click to open controls." : "Open Radcap"
        button.setAccessibilityLabel(recording ? "Radcap menu bar item, recording" : "Radcap menu bar item")
        button.setAccessibilityValue(recording ? "Recording" : "Idle")
    }
}
