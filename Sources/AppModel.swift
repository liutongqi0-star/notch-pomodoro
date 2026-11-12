import AppKit
import Combine

enum UsageState {
    case active
    case idle
    case locked
    case asleep

    var title: String {
        switch self {
        case .active: return "使用中"
        case .idle: return "空闲 · 已暂停"
        case .locked: return "屏幕已锁定"
        case .asleep: return "屏幕已休眠"
        }
    }
}

final class AppModel: NSObject, ObservableObject {
    @Published private(set) var todaySeconds: Double = 0
    @Published private(set) var totalSeconds: Double = 0
    @Published private(set) var sessionSeconds: Double = 0
    @Published private(set) var state: UsageState = .active

    @Published var memoText: String {
        didSet { scheduleMemoSave() }
    }

    @Published var pauseWhenIdle: Bool {
        didSet { defaults.set(pauseWhenIdle, forKey: Keys.pauseWhenIdle) }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            guard oldValue != launchAtLogin else { return }
            do {
                try LoginItem.setEnabled(launchAtLogin)
            } catch {
                NSLog("UsageClock: 更新登录项失败：\(error.localizedDescription)")
                presentError("无法更新「登录时自动启动」", message: error.localizedDescription)
            }
        }
    }

    var isActive: Bool {
        if case .active = state { return true }
        return false
    }

    private enum Keys {
        static let pauseWhenIdle = "pauseWhenIdle"
    }

    private static let idleThreshold: TimeInterval = 5 * 60

    let pomodoro: PomodoroEngine
    let theme: ThemeModel

    private let defaults = UserDefaults.standard
    private let store: UsageStore
    private let memoStore: MemoStore
    private var data: UsageData
    private var memoWork: DispatchWorkItem?
    private var timer: Timer?
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var lastSave = ProcessInfo.processInfo.systemUptime
    private var dirty = false
    private var activityToken: NSObjectProtocol?
    private var signalSources: [DispatchSourceSignal] = []

    override init() {
        let store = UsageStore()
        self.store = store
        self.data = store.load() ?? UsageData()

        let memoStore = MemoStore(directory: store.directory)
        self.memoStore = memoStore
        self.memoText = memoStore.load()
        self.pomodoro = PomodoroEngine()
        self.theme = ThemeModel(directory: store.directory)

        pauseWhenIdle = defaults.bool(forKey: Keys.pauseWhenIdle)
        launchAtLogin = LoginItem.isEnabled()

        super.init()

        totalSeconds = data.days.values.reduce(0, +)
        todaySeconds = data.days[TimeFormat.dayKey(Date())] ?? 0
        lastTick = ProcessInfo.processInfo.systemUptime
        lastSave = lastTick
        if ProcessInfo.processInfo.environment["USAGECLOCK_RENDER_PREVIEW"] != "1" {
            start()
        }
    }

    deinit {
        timer?.invalidate()
        memoWork?.cancel()
        if let activityToken {
            ProcessInfo.processInfo.endActivity(activityToken)
        }
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    // MARK: - 生命周期

    private func start() {
        LoginItem.refreshIfEnabled()

        // 避免 App Nap 让秒表停摆；允许系统正常休眠。
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep, .suddenTerminationDisabled],
            reason: "UsageClock 需要持续记录使用时长"
        )

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        timer.tolerance = 0.08
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        // 被 pkill / 注销时也先保存，避免丢失最后一段时间
        for sig in [SIGTERM, SIGINT] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler { [weak self] in
                self?.persistNow()
                NSApp.terminate(nil)
            }
            source.resume()
            signalSources.append(source)
        }

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceCenter.addObserver(self, selector: #selector(handleSleep), name: NSWorkspace.willSleepNotification, object: nil)
        workspaceCenter.addObserver(self, selector: #selector(handleSleep), name: NSWorkspace.screensDidSleepNotification, object: nil)
        workspaceCenter.addObserver(self, selector: #selector(handleWake), name: NSWorkspace.didWakeNotification, object: nil)
        workspaceCenter.addObserver(self, selector: #selector(handleWake), name: NSWorkspace.screensDidWakeNotification, object: nil)
    }

    @objc private func handleSleep() {
        persistNow()
    }

    @objc private func handleWake() {
        lastTick = ProcessInfo.processInfo.systemUptime
    }

    // MARK: - 计时

    private func tick() {
        pomodoro.tick()

        let now = ProcessInfo.processInfo.systemUptime
        let delta = min(max(now - lastTick, 0), 2.5)
        lastTick = now

        let previousState = state
        let newState = detectState()
        if newState != state {
            state = newState
            if previousState == .active {
                persistNow()
            }
        }

        let key = TimeFormat.dayKey(Date())

        if newState == .active {
            data.days[key, default: 0] += delta
            sessionSeconds += delta
            todaySeconds = data.days[key] ?? 0
            totalSeconds += delta
            dirty = true
        } else {
            todaySeconds = data.days[key] ?? 0
        }

        if dirty && now - lastSave >= 20 {
            persistNow()
        }
    }

    private func detectState() -> UsageState {
        if isScreenLocked() { return .locked }
        if areAllDisplaysAsleep() { return .asleep }
        if pauseWhenIdle {
            let idle = CGEventSource.secondsSinceLastEventType(
                .combinedSessionState,
                eventType: CGEventType(rawValue: ~0)!
            )
            if idle > Self.idleThreshold { return .idle }
        }
        return .active
    }

    /// 所有在线显示器都休眠时才算屏幕休眠；外接显示器亮着时继续计时。
    private func areAllDisplaysAsleep() -> Bool {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return false }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &displays, &count) == .success else { return false }
        return displays.prefix(Int(count)).allSatisfy { CGDisplayIsAsleep($0) != 0 }
    }

    /// 锁屏、切换到登录窗口，或者当前会话不在前台时，都视为未在使用。
    private func isScreenLocked() -> Bool {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        if let locked = session["CGSSessionScreenIsLocked"] as? Bool, locked { return true }
        if let onConsole = session["kCGSSessionOnConsoleKey"] as? Bool, !onConsole { return true }
        return false
    }

    // MARK: - 持久化

    func persistNow() {
        saveMemoNow()
        guard dirty else { return }
        do {
            try store.save(data)
            dirty = false
            lastSave = ProcessInfo.processInfo.systemUptime
        } catch {
            NSLog("UsageClock: 保存记录失败：\(error.localizedDescription)")
        }
    }

    // MARK: - 备忘录

    private func scheduleMemoSave() {
        memoWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.saveMemoNow()
        }
        memoWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    func saveMemoNow() {
        memoWork?.cancel()
        do {
            try memoStore.save(memoText)
        } catch {
            NSLog("UsageClock: 保存备忘录失败：\(error.localizedDescription)")
        }
    }

    func clearMemo() {
        memoText = ""
        saveMemoNow()
    }

    func confirmClearMemo() {
        guard !memoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "清空备忘录？"
        alert.informativeText = "会删除备忘录里的全部文字，此操作无法撤销。"
        alert.addButton(withTitle: "取消")
        alert.addButton(withTitle: "清空")
        if alert.runModal() == .alertSecondButtonReturn {
            clearMemo()
        }
    }

    func resetStatistics() {
        data.days = [:]
        data.installedAt = Date()
        todaySeconds = 0
        totalSeconds = 0
        sessionSeconds = 0
        dirty = true
        persistNow()
    }

    func confirmReset() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "重置累计使用时长？"
        alert.informativeText = "会清空所有已记录的时长（包括今日与本次会话），此操作无法撤销。"
        alert.addButton(withTitle: "取消")
        alert.addButton(withTitle: "重置")
        if alert.runModal() == .alertSecondButtonReturn {
            resetStatistics()
        }
    }

    func openDataFolder() {
        try? FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        NSWorkspace.shared.open(store.directory)
    }

    /// 仅用于生成展示图
    func applyPreviewValues(total: Double, today: Double, session: Double) {
        totalSeconds = total
        todaySeconds = today
        sessionSeconds = session
        state = .active
    }

    private func presentError(_ title: String, message: String) {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = title
            alert.informativeText = message
            alert.addButton(withTitle: "好")
            alert.runModal()
        }
    }
}
