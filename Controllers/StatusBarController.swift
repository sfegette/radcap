import AppKit
import Combine

final class StatusBarController {
    private let statusItem: NSStatusItem
    private var cancellables = Set<AnyCancellable>()
    private var blinkTimer: Timer?
    private var blinkOn = true

    var onToggleWindow: (() -> Void)?

    init(captureManager: CaptureManager) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
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

        let windowItem = NSMenuItem(title: "Show / Hide Window", action: #selector(toggleWindow), keyEquivalent: "")
        windowItem.target = self
        menu.addItem(windowItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Madcap", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func toggleWindow() { onToggleWindow?() }

    // MARK: - Icon

    private func updateForRecording(_ isRecording: Bool) {
        blinkTimer?.invalidate()
        blinkTimer = nil

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

        let symbolName: String
        if recording {
            symbolName = blink ? "record.circle.fill" : "record.circle"
        } else {
            symbolName = "video.circle"
        }

        guard let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else { return }

        let sizeConfig = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let finalConfig: NSImage.SymbolConfiguration

        if recording && blink {
            // Red dot while recording (blink on)
            let colorConfig = NSImage.SymbolConfiguration(paletteColors: [.systemRed])
            finalConfig = sizeConfig.applying(colorConfig)
        } else {
            finalConfig = sizeConfig
        }

        let configured = image.withSymbolConfiguration(finalConfig) ?? image
        if !(recording && blink) {
            configured.isTemplate = true
        }
        button.image = configured
    }
}
