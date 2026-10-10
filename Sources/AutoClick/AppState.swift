import AppKit
import Carbon

enum PositionMode: String, Codable, CaseIterable, Identifiable {
    case cursor, fixed
    var id: Self { self }
    var title: String { self == .cursor ? "Theo con trỏ" : "Điểm cố định" }
}

enum StopMode: String, Codable, CaseIterable, Identifiable {
    case never, count, duration
    var id: Self { self }

    var title: String {
        switch self {
        case .never: "Không"
        case .count: "Số lần"
        case .duration: "Thời gian"
        }
    }
}

struct Settings: Codable {
    var clickType: ClickType = .left
    var intervalMs = 100
    var jitterMs = 0
    var positionMode: PositionMode = .cursor
    var fixedX: Double = 0
    var fixedY: Double = 0
    var stopMode: StopMode = .never
    var stopCount = 100
    var stopSeconds = 60
    /// 0 = lặp vô hạn
    var playbackRepeat = 1
    var playbackSpeed = 1.0
}

struct RecordedClick: Codable, Identifiable {
    var id = UUID()
    /// Số giây chờ kể từ thao tác trước (hoặc từ lúc bắt đầu ghi với thao tác đầu tiên).
    var delay: Double
    var x: Double
    var y: Double
    var button: MouseButton
    var clickCount: Int
}

@MainActor
final class AppState: ObservableObject {
    @Published var settings: Settings {
        didSet { Storage.save(settings, key: "settings") }
    }
    @Published private(set) var recording: [RecordedClick] {
        didSet { Storage.save(recording, key: "recording") }
    }

    @Published private(set) var isClicking = false
    @Published private(set) var isRecording = false
    @Published private(set) var isPlaying = false
    @Published private(set) var clickCount = 0
    @Published private(set) var playbackStatus = ""
    @Published private(set) var pickCountdown: Int?
    @Published private(set) var hasAccessibility = Permissions.isTrusted

    private var clickTask: Task<Void, Never>?
    private var playTask: Task<Void, Never>?
    private var pickTask: Task<Void, Never>?
    private var recordMonitor: Any?
    private var lastRecordTime: TimeInterval = 0
    private var escMonitors: [Any] = []
    private var permissionTimer: Timer?

    var menuIcon: String {
        if isRecording { return "record.circle.fill" }
        if isClicking || isPlaying { return "cursorarrow.click.2" }
        return "cursorarrow.click"
    }

    init() {
        settings = Storage.load("settings") ?? Settings()
        recording = Storage.load("recording") ?? []
        setupHotKeys()
        installEscMonitors()
        if !hasAccessibility {
            Permissions.prompt()
            watchPermission()
        }
    }

    // MARK: - Auto click

    func toggleClicking() {
        isClicking ? stopClicking() : startClicking()
    }

    func startClicking() {
        guard ensurePermission() else { return }
        stopAll()
        isClicking = true
        clickCount = 0
        let start = Date()

        clickTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                let s = self.settings
                if s.stopMode == .count, self.clickCount >= s.stopCount { break }
                if s.stopMode == .duration, Date().timeIntervalSince(start) >= Double(s.stopSeconds) { break }
                if Clicker.isInStopCorner() { break }

                let point = s.positionMode == .cursor
                    ? Clicker.cursorLocation
                    : CGPoint(x: s.fixedX, y: s.fixedY)
                Clicker.perform(s.clickType, at: point)
                self.clickCount += 1

                let jitter = s.jitterMs > 0 ? Int.random(in: -s.jitterMs...s.jitterMs) : 0
                let delayMs = max(1, s.intervalMs + jitter)
                try? await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
            }
            if !Task.isCancelled { self?.stopClicking() }
        }
    }

    func stopClicking() {
        clickTask?.cancel()
        clickTask = nil
        isClicking = false
    }

    /// Đếm ngược 3 giây rồi lấy vị trí con trỏ làm điểm cố định.
    func pickFixedPoint() {
        pickTask?.cancel()
        pickTask = Task { [weak self] in
            for i in stride(from: 3, to: 0, by: -1) {
                self?.pickCountdown = i
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
            }
            let p = Clicker.cursorLocation
            self?.settings.fixedX = p.x.rounded()
            self?.settings.fixedY = p.y.rounded()
            self?.pickCountdown = nil
        }
    }

    // MARK: - Ghi lại

    func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    func startRecording() {
        guard ensurePermission() else { return }
        stopAll()
        recording = []
        lastRecordTime = ProcessInfo.processInfo.systemUptime
        // Global monitor không nhận click vào chính app này, nên thao tác trên menu không bị ghi.
        recordMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            let location = event.cgEvent?.location ?? Clicker.cursorLocation
            let button: MouseButton = event.type == .rightMouseDown ? .right : .left
            let timestamp = event.timestamp
            let clickCount = event.clickCount
            Task { @MainActor in
                self?.appendRecorded(location: location, button: button,
                                     timestamp: timestamp, clickCount: clickCount)
            }
        }
        isRecording = true
    }

    func stopRecording() {
        if let recordMonitor { NSEvent.removeMonitor(recordMonitor) }
        recordMonitor = nil
        isRecording = false
    }

    func clearRecording() {
        recording = []
    }

    private func appendRecorded(location: CGPoint, button: MouseButton, timestamp: TimeInterval, clickCount: Int) {
        guard isRecording else { return }
        let delay = max(0, timestamp - lastRecordTime)
        lastRecordTime = timestamp
        recording.append(RecordedClick(delay: delay, x: location.x, y: location.y,
                                       button: button, clickCount: max(1, clickCount)))
    }

    // MARK: - Phát lại

    func togglePlayback() {
        isPlaying ? stopPlayback() : startPlayback()
    }

    func startPlayback() {
        guard !recording.isEmpty, ensurePermission() else { return }
        stopAll()
        isPlaying = true
        let items = recording
        let repeats = settings.playbackRepeat
        let speed = max(0.1, settings.playbackSpeed)

        playTask = Task { [weak self] in
            var round = 0
            outer: while !Task.isCancelled, repeats == 0 || round < repeats {
                round += 1
                for (index, item) in items.enumerated() {
                    self?.playbackStatus = "Lượt \(round)\(repeats == 0 ? "" : "/\(repeats)") · \(index + 1)/\(items.count)"
                    // Luôn chờ tối thiểu 10ms để không khoá main thread khi lặp vô hạn.
                    let wait = max(0.01, item.delay / speed)
                    try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
                    if Task.isCancelled || Clicker.isInStopCorner() { break outer }
                    Clicker.click(item.button, at: CGPoint(x: item.x, y: item.y),
                                  clickState: Int64(item.clickCount))
                }
            }
            if !Task.isCancelled { self?.stopPlayback() }
        }
    }

    func stopPlayback() {
        playTask?.cancel()
        playTask = nil
        isPlaying = false
        playbackStatus = ""
    }

    // MARK: - Chung

    func stopAll() {
        stopClicking()
        stopRecording()
        stopPlayback()
    }

    private func ensurePermission() -> Bool {
        hasAccessibility = Permissions.isTrusted
        if !hasAccessibility {
            Permissions.prompt()
            watchPermission()
        }
        return hasAccessibility
    }

    /// Kiểm tra định kỳ cho tới khi người dùng cấp quyền, rồi cài lại monitor phím Esc.
    private func watchPermission() {
        guard permissionTimer == nil else { return }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, Permissions.isTrusted else { return }
                self.hasAccessibility = true
                self.permissionTimer?.invalidate()
                self.permissionTimer = nil
                self.installEscMonitors()
            }
        }
    }

    private func setupHotKeys() {
        let mods = controlKey | optionKey
        HotKeyCenter.shared.register(id: 1, keyCode: kVK_ANSI_S, modifiers: mods) { [weak self] in
            self?.toggleClicking()
        }
        HotKeyCenter.shared.register(id: 2, keyCode: kVK_ANSI_R, modifiers: mods) { [weak self] in
            self?.toggleRecording()
        }
        HotKeyCenter.shared.register(id: 3, keyCode: kVK_ANSI_P, modifiers: mods) { [weak self] in
            self?.togglePlayback()
        }
    }

    private func installEscMonitors() {
        escMonitors.forEach(NSEvent.removeMonitor)
        escMonitors = []
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            guard event.keyCode == UInt16(kVK_Escape) else { return }
            Task { @MainActor in self?.stopAll() }
        }) {
            escMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            if event.keyCode == UInt16(kVK_Escape) {
                Task { @MainActor in self?.stopAll() }
            }
            return event
        }) {
            escMonitors.append(local)
        }
    }
}
