import AppKit
import Combine
#if !MAS_BUILD
import Sparkle
#endif

final class StatusBarController {
    private let statusItem: NSStatusItem
    private var cancellables = Set<AnyCancellable>()

    var onToggleWindow: (() -> Void)?
    weak var coordinator: RecordingCoordinator?
    #if !MAS_BUILD
    weak var updaterController: SPUStandardUpdaterController?
    #endif

    init(captureManager: CaptureManager) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setupButton()
        setIcon(recording: false)
        observeRecording(captureManager)
    }

    deinit {
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
        } else if coordinator?.captureManager.isRecording == true {
            coordinator?.stopFlow()
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

        #if !MAS_BUILD
        if let updaterController {
            menu.addItem(.separator())
            let updateItem = NSMenuItem(
                title: "Check for Updates…",
                action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
                keyEquivalent: ""
            )
            updateItem.target = updaterController
            menu.addItem(updateItem)
        }
        #endif

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
        updateAccessibility(recording: isRecording)
        setIcon(recording: isRecording)
    }

    private func setIcon(recording: Bool) {
        guard let button = statusItem.button else { return }
        if recording {
            // record.circle.fill: outer ring in labelColor, inner disc in red.
            // paletteColors[0] = primary layer (ring), paletteColors[1] = secondary layer (fill).
            let sizeConfig  = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            let colorConfig = NSImage.SymbolConfiguration(paletteColors: [NSColor.labelColor, .systemRed])
            if let img = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "Recording")?
                .withSymbolConfiguration(sizeConfig.applying(colorConfig)) {
                button.image = img
                button.contentTintColor = nil
            }
        } else {
            guard let image = NSImage(named: "MenubarIcon") else { return }
            image.isTemplate = true
            image.size = NSSize(width: 18, height: 18)
            button.image = image
            button.contentTintColor = nil
        }
    }

    private func updateAccessibility(recording: Bool) {
        guard let button = statusItem.button else { return }
        button.toolTip = recording ? "Radcap is recording. Click to stop." : "Open Radcap"
        button.setAccessibilityLabel(recording ? "Radcap menu bar item, recording" : "Radcap menu bar item")
        button.setAccessibilityValue(recording ? "Recording" : "Idle")
    }
}
