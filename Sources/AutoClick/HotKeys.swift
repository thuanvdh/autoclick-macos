import Carbon

/// Phím tắt toàn cục qua Carbon `RegisterEventHotKey` (không cần quyền Accessibility).
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    private static let signature: OSType = 0x41434C4B // "ACLK"
    private var handlers: [UInt32: @MainActor () -> Void] = [:]
    private var refs: [EventHotKeyRef] = []
    private var installed = false

    func register(id: UInt32, keyCode: Int, modifiers: Int, handler: @escaping @MainActor () -> Void) {
        installIfNeeded()
        handlers[id] = handler
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        let status = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), hotKeyID,
                                         GetApplicationEventTarget(), 0, &ref)
        if status == noErr, let ref {
            refs.append(ref)
        } else {
            NSLog("AutoClick: không đăng ký được hotkey id=\(id) (status \(status))")
        }
    }

    fileprivate func fire(id: UInt32) {
        guard let handler = handlers[id] else { return }
        Task { @MainActor in handler() }
    }

    private func installIfNeeded() {
        guard !installed else { return }
        installed = true
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), hotKeyHandler, 1, &eventType, nil, nil)
    }
}

private func hotKeyHandler(_ next: EventHandlerCallRef?, _ event: EventRef?,
                           _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                   EventParamType(typeEventHotKeyID), nil,
                                   MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
    guard status == noErr else { return status }
    HotKeyCenter.shared.fire(id: hotKeyID.id)
    return noErr
}
