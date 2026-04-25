import Carbon.HIToolbox

// Registers a system-wide ⌘⌥R hotkey via Carbon RegisterEventHotKey.
// Does not require Accessibility permission — works while any app is frontmost.
final class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()
    private init() {}

    var action: (() -> Void)?
    private var handlerRef: EventHandlerRef?
    private var hotkeyRef: EventHotKeyRef?

    func register() {
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let ptr = userData, let event else { return OSStatus(eventNotHandledErr) }
                var hkID = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                  EventParamType(typeEventHotKeyID), nil,
                                  MemoryLayout<EventHotKeyID>.size, nil, &hkID)
                guard hkID.signature == 0x52434150, hkID.id == 1 else {
                    return OSStatus(eventNotHandledErr)
                }
                let mgr = Unmanaged<GlobalHotkeyManager>.fromOpaque(ptr).takeUnretainedValue()
                DispatchQueue.main.async { mgr.action?() }
                return noErr
            },
            1, &spec, selfPtr, &handlerRef
        )

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = 0x52434150  // 'RCAP'
        hotKeyID.id = 1

        RegisterEventHotKey(
            UInt32(kVK_ANSI_R),
            UInt32(cmdKey | optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )
    }

    func unregister() {
        if let ref = hotkeyRef { UnregisterEventHotKey(ref); hotkeyRef = nil }
        if let ref = handlerRef { RemoveEventHandler(ref); handlerRef = nil }
    }

    deinit { unregister() }
}
