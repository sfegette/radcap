import AppKit
import Combine
import Carbon.HIToolbox

final class RecordingCoordinator: ObservableObject {

    let captureManager: CaptureManager
    weak var floatingWindowController: FloatingWindowController?
    @Published private(set) var isCountingDown = false

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
        guard !captureManager.isRecording, !isCountingDown else { return }
        isCountingDown = true
        captureManager.prepareForRecording()  // lock focus/exposure/WB before countdown so first frame is clean (#29)
        floatingWindowController?.hide(stopCamera: false)  // keep session live through countdown
        countdownController.show(from: 3) { [weak self] in
            guard let self else { return }
            self.isCountingDown = false
            guard self.captureManager.startRecording() else {
                self.floatingWindowController?.show()
                return
            }
            self.hudController.show()
            self.registerSpeedHotkeys()
            NSAccessibility.post(
                element: NSApp as Any,
                notification: .announcementRequested,
                userInfo: [.announcement: "Recording started", .priority: NSAccessibilityPriorityLevel.high.rawValue]
            )
        }
    }

    func stopFlow() {
        guard captureManager.isRecording else { return }
        unregisterSpeedHotkeys()
        speedOverlay.dismiss()
        captureManager.stopRecording()
        captureManager.unprepareForRecording()  // restore continuous auto modes (#29)
        hudController.hide()
        floatingWindowController?.show()
        NSAccessibility.post(
            element: NSApp as Any,
            notification: .announcementRequested,
            userInfo: [.announcement: "Recording stopped", .priority: NSAccessibilityPriorityLevel.high.rawValue]
        )
    }

    // MARK: - Speed hotkeys (↑ / ↓ during recording)

    private func registerSpeedHotkeys() {
        guard speedHandlerRef == nil, upHotkeyRef == nil, dnHotkeyRef == nil else { return }
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
        let newSpeed = max(0.25, min(2.0, s * (1 + fraction)))
        AppSettings.shared.teleprompterSpeed = newSpeed
        speedOverlay.show(speed: newSpeed)
    }
}
