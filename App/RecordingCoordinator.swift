import AppKit
import Combine
import Carbon.HIToolbox

final class RecordingCoordinator: ObservableObject {

    let captureManager: CaptureManager
    weak var floatingWindowController: FloatingWindowController?

    private lazy var countdownController = CountdownWindowController()
    private lazy var hudController = RecordingHUDController(captureManager: captureManager)
    private lazy var speedOverlay = SpeedChangeOverlayController()

    // Arrow-key speed hotkeys — active only while recording
    private var speedHandlerRef: EventHandlerRef?
    private var upHotkeyRef: EventHotKeyRef?
    private var dnHotkeyRef: EventHotKeyRef?

    init(captureManager: CaptureManager) {
        self.captureManager = captureManager
    }

    func startFlow() {
        floatingWindowController?.hide(stopCamera: false)  // keep session live through countdown
        countdownController.show(from: 3) { [weak self] in
            guard let self else { return }
            self.captureManager.startRecording()
            self.hudController.show()
            self.registerSpeedHotkeys()
        }
    }

    func stopFlow() {
        unregisterSpeedHotkeys()
        speedOverlay.dismiss()
        captureManager.stopRecording()
        hudController.hide()
        floatingWindowController?.show()
    }

    // MARK: - Speed hotkeys (↑ / ↓ during recording)

    private func registerSpeedHotkeys() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let event, let ptr = userData else { return OSStatus(eventNotHandledErr) }
                var hkID = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                  EventParamType(typeEventHotKeyID), nil,
                                  MemoryLayout<EventHotKeyID>.size, nil, &hkID)
                guard hkID.signature == 0x52434150 else { return OSStatus(eventNotHandledErr) }
                let coord = Unmanaged<RecordingCoordinator>.fromOpaque(ptr).takeUnretainedValue()
                switch hkID.id {
                case 2: DispatchQueue.main.async { coord.adjustSpeed(by:  0.05) }; return noErr
                case 3: DispatchQueue.main.async { coord.adjustSpeed(by: -0.05) }; return noErr
                default: return OSStatus(eventNotHandledErr)
                }
            },
            1, &spec, selfPtr, &speedHandlerRef
        )

        var upID = EventHotKeyID(); upID.signature = 0x52434150; upID.id = 2
        RegisterEventHotKey(UInt32(kVK_UpArrow), 0, upID,
                            GetApplicationEventTarget(), 0, &upHotkeyRef)

        var dnID = EventHotKeyID(); dnID.signature = 0x52434150; dnID.id = 3
        RegisterEventHotKey(UInt32(kVK_DownArrow), 0, dnID,
                            GetApplicationEventTarget(), 0, &dnHotkeyRef)
    }

    private func unregisterSpeedHotkeys() {
        if let r = upHotkeyRef       { UnregisterEventHotKey(r); upHotkeyRef = nil }
        if let r = dnHotkeyRef       { UnregisterEventHotKey(r); dnHotkeyRef = nil }
        if let r = speedHandlerRef   { RemoveEventHandler(r);    speedHandlerRef = nil }
    }

    // Relative ±5 % adjustment, clamped to a sensible range.
    private func adjustSpeed(by fraction: Double) {
        let s = AppSettings.shared.teleprompterSpeed
        let newSpeed = max(0.1, min(5.0, s * (1 + fraction)))
        AppSettings.shared.teleprompterSpeed = newSpeed
        speedOverlay.show(speed: newSpeed)
    }
}
