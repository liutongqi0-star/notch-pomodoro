import AppKit
import Combine

enum PomodoroPhase: String, CaseIterable {
    case focus
    case shortBreak
    case longBreak

    var title: String {
        switch self {
        case .focus: return "专注"
        case .shortBreak: return "短休息"
        case .longBreak: return "长休息"
        }
    }

    var symbolName: String {
        switch self {
        case .focus: return "timer"
        case .shortBreak: return "cup.and.saucer.fill"
        case .longBreak: return "moon.zzz.fill"
        }
    }
}

enum PomodoroState: Equatable {
    case ready
    case running
    case paused
    case completed

    var isRunning: Bool { self == .running }
    var isPaused: Bool { self == .paused }
    var isCompleted: Bool { self == .completed }
}

extension Notification.Name {
    static let pomodoroPhaseCompleted = Notification.Name("UsageClock.pomodoroPhaseCompleted")
}

/// 25 / 5 / 15 的番茄钟状态机。真正倒计时用结束时间计算，休眠或卡顿后不会漂移。
final class PomodoroEngine: ObservableObject {
    @Published private(set) var phase: PomodoroPhase = .focus
    @Published private(set) var state: PomodoroState = .ready
    @Published private(set) var remaining: TimeInterval = 25 * 60
    @Published private(set) var todayFocusCount: Int = 0
    @Published private(set) var focusStreak: Int = 0

    @Published var focusMinutes: Int = 25 {
        didSet { durationChanged() }
    }
    @Published var shortBreakMinutes: Int = 5 {
        didSet { durationChanged() }
    }
    @Published var longBreakMinutes: Int = 15 {
        didSet { durationChanged() }
    }
    @Published var roundsBeforeLongBreak: Int = 4 {
        didSet {
            guard oldValue != roundsBeforeLongBreak else { return }
            if roundsBeforeLongBreak < 2 { roundsBeforeLongBreak = 2; return }
            if roundsBeforeLongBreak > 8 { roundsBeforeLongBreak = 8; return }
            defaults.set(roundsBeforeLongBreak, forKey: Keys.rounds)
        }
    }
    @Published var soundEnabled: Bool = true {
        didSet { defaults.set(soundEnabled, forKey: Keys.sound) }
    }

    private enum Keys {
        static let focusMinutes = "pomodoro.focusMinutes"
        static let shortBreakMinutes = "pomodoro.shortBreakMinutes"
        static let longBreakMinutes = "pomodoro.longBreakMinutes"
        static let rounds = "pomodoro.roundsBeforeLongBreak"
        static let sound = "pomodoro.soundEnabled"
        static let streak = "pomodoro.focusStreak"
        static let todayPrefix = "pomodoro.today."
    }

    private let defaults = UserDefaults.standard
    private var endDate: Date?
    private var completionSound: NSSound?
    private var todayKey: String
    private var lastRoundedRemaining: Int = 25 * 60

    init() {
        let defaults = UserDefaults.standard
        let focus = defaults.object(forKey: Keys.focusMinutes) as? Int ?? 25
        let shortBreak = defaults.object(forKey: Keys.shortBreakMinutes) as? Int ?? 5
        let longBreak = defaults.object(forKey: Keys.longBreakMinutes) as? Int ?? 15
        let rounds = defaults.object(forKey: Keys.rounds) as? Int ?? 4

        focusMinutes = min(max(focus, 1), 180)
        shortBreakMinutes = min(max(shortBreak, 1), 60)
        longBreakMinutes = min(max(longBreak, 1), 120)
        roundsBeforeLongBreak = min(max(rounds, 2), 8)
        soundEnabled = defaults.object(forKey: Keys.sound) as? Bool ?? true
        focusStreak = max(0, defaults.integer(forKey: Keys.streak))

        let key = TimeFormat.dayKey(Date())
        todayKey = key
        todayFocusCount = max(0, defaults.integer(forKey: Keys.todayPrefix + key))

        remaining = TimeInterval(focusMinutes * 60)
        lastRoundedRemaining = Int(remaining)

        // 仅用于本地截图和自动化验证：用一个很短的专注时间启动。
        if let raw = ProcessInfo.processInfo.environment["USAGECLOCK_TEST_POMODORO_SECONDS"],
           let seconds = Double(raw), seconds > 0 {
            remaining = seconds
            lastRoundedRemaining = Int(ceil(seconds))
            state = .running
            endDate = Date().addingTimeInterval(seconds)
        }
    }

    // MARK: - 展示

    var phaseDuration: TimeInterval {
        TimeInterval(minutes(for: phase) * 60)
    }

    var progress: Double {
        let total = phaseDuration
        guard total > 0 else { return 0 }
        if state == .completed { return 1 }
        return min(1, max(0, 1 - remaining / total))
    }

    var roundedRemaining: Int {
        max(0, Int(ceil(remaining)))
    }

    var nextPhase: PomodoroPhase {
        guard phase == .focus else { return .focus }
        if focusStreak > 0, focusStreak % roundsBeforeLongBreak == 0 {
            return .longBreak
        }
        return .shortBreak
    }

    var nextPhaseMinutes: Int {
        minutes(for: nextPhase)
    }

    var primaryActionTitle: String {
        switch state {
        case .running: return "暂停"
        case .paused: return "继续"
        case .ready: return phase == .focus ? "开始专注" : "开始休息"
        case .completed: return phase == .focus ? "开始休息" : "开始专注"
        }
    }

    var stateTitle: String {
        switch state {
        case .ready: return "准备开始"
        case .running: return "进行中"
        case .paused: return "已暂停"
        case .completed: return "时间到"
        }
    }

    var cycleTitle: String {
        if phase == .longBreak { return "长休息" }
        if phase == .focus {
            if focusStreak > 0, focusStreak % roundsBeforeLongBreak == 0 {
                return "第 \(roundsBeforeLongBreak)/\(roundsBeforeLongBreak) 轮"
            }
            let current = focusStreak % roundsBeforeLongBreak + 1
            return "第 \(current)/\(roundsBeforeLongBreak) 轮"
        }
        return "短暂放松"
    }

    var subtitle: String {
        switch (phase, state) {
        case (.focus, .completed):
            return "休息 \(nextPhaseMinutes) 分钟，或稍后继续"
        case (.focus, .running):
            return "保持专注 · 结束后提醒"
        case (.focus, .paused):
            return "已暂停 · 点继续回到专注"
        case (.focus, .ready):
            return "每 \(roundsBeforeLongBreak) 轮专注后长休息"
        case (.shortBreak, .completed), (.longBreak, .completed):
            return "开始下一轮 \(focusMinutes) 分钟专注"
        case (.shortBreak, .running):
            return "放松一下 · 结束后提醒"
        case (.longBreak, .running):
            return "好好休息 · 结束后提醒"
        case (.shortBreak, .paused), (.longBreak, .paused):
            return "休息已暂停"
        case (.shortBreak, .ready):
            return "休息 \(shortBreakMinutes) 分钟"
        case (.longBreak, .ready):
            return "长休息 \(longBreakMinutes) 分钟"
        }
    }

    var bottomHint: String {
        switch phase {
        case .focus: return "专注 \(focusMinutes)m"
        case .shortBreak: return "休息 \(shortBreakMinutes)m"
        case .longBreak: return "长休息 \(longBreakMinutes)m"
        }
    }

    // MARK: - 操作

    func toggle() {
        switch state {
        case .running:
            pause()
        case .paused, .ready:
            start()
        case .completed:
            startNextPhase()
        }
    }

    func start() {
        guard state != .running else { return }
        if state == .completed {
            startNextPhase()
            return
        }
        if remaining <= 0 {
            remaining = phaseDuration
        }
        endDate = Date().addingTimeInterval(remaining)
        lastRoundedRemaining = roundedRemaining
        state = .running
    }

    func pause() {
        guard state == .running else { return }
        updateRemaining()
        endDate = nil
        state = .paused
    }

    /// 开始下一阶段并立即计时。
    func startNextPhase() {
        phase = nextPhase
        remaining = phaseDuration
        lastRoundedRemaining = Int(remaining)
        endDate = Date().addingTimeInterval(remaining)
        state = .running
    }

    /// 重置当前阶段，不改变阶段类型。
    func reset() {
        endDate = nil
        remaining = phaseDuration
        lastRoundedRemaining = Int(remaining)
        state = .ready
    }

    /// 跳过当前阶段，停在下一阶段的准备状态。
    func skip() {
        if phase == .longBreak {
            focusStreak = 0
            defaults.set(focusStreak, forKey: Keys.streak)
        }
        phase = nextPhase
        endDate = nil
        remaining = phaseDuration
        lastRoundedRemaining = Int(remaining)
        state = .ready
    }

    /// 番茄钟只在主线程的 1 秒 tick 中推进；倒计时本身依赖结束时间。
    func tick() {
        refreshDayIfNeeded()
        guard state == .running, let endDate else { return }
        let raw = endDate.timeIntervalSinceNow
        if raw <= 0 {
            remaining = 0
            completeCurrentPhase()
            return
        }
        remaining = raw
        let rounded = Int(ceil(raw))
        if rounded != lastRoundedRemaining {
            lastRoundedRemaining = rounded
        }
    }

    // MARK: - 内部

    private func completeCurrentPhase() {
        endDate = nil
        state = .completed

        if phase == .focus {
            todayFocusCount += 1
            focusStreak += 1
            defaults.set(todayFocusCount, forKey: Keys.todayPrefix + todayKey)
            defaults.set(focusStreak, forKey: Keys.streak)
        } else if phase == .longBreak {
            focusStreak = 0
            defaults.set(focusStreak, forKey: Keys.streak)
        }

        playCompletionSound()
        NotificationCenter.default.post(
            name: .pomodoroPhaseCompleted,
            object: self,
            userInfo: ["phase": phase.rawValue]
        )
    }

    private func playCompletionSound() {
        guard soundEnabled else { return }
        let name = phase == .focus ? "Glass" : "Ping"
        if let sound = NSSound(named: NSSound.Name(name)) {
            completionSound = sound
            sound.play()
        } else {
            NSSound.beep()
        }
    }

    private func updateRemaining() {
        guard let endDate else { return }
        remaining = max(0, endDate.timeIntervalSinceNow)
    }

    private func refreshDayIfNeeded() {
        let key = TimeFormat.dayKey(Date())
        guard key != todayKey else { return }
        todayKey = key
        todayFocusCount = max(0, defaults.integer(forKey: Keys.todayPrefix + key))
    }

    private func minutes(for phase: PomodoroPhase) -> Int {
        switch phase {
        case .focus: return focusMinutes
        case .shortBreak: return shortBreakMinutes
        case .longBreak: return longBreakMinutes
        }
    }

    private func durationChanged() {
        normalizeDurations()
        if state == .ready {
            remaining = phaseDuration
            lastRoundedRemaining = Int(remaining)
        }
        persistDurations()
    }

    private func normalizeDurations() {
        if focusMinutes < 1 { focusMinutes = 1; return }
        if focusMinutes > 180 { focusMinutes = 180; return }
        if shortBreakMinutes < 1 { shortBreakMinutes = 1; return }
        if shortBreakMinutes > 60 { shortBreakMinutes = 60; return }
        if longBreakMinutes < 1 { longBreakMinutes = 1; return }
        if longBreakMinutes > 120 { longBreakMinutes = 120; return }
    }

    private func persistDurations() {
        defaults.set(focusMinutes, forKey: Keys.focusMinutes)
        defaults.set(shortBreakMinutes, forKey: Keys.shortBreakMinutes)
        defaults.set(longBreakMinutes, forKey: Keys.longBreakMinutes)
        defaults.set(roundsBeforeLongBreak, forKey: Keys.rounds)
    }

    // MARK: - 展示图

    func applyPreview(
        phase: PomodoroPhase,
        state: PomodoroState,
        remaining: TimeInterval,
        todayFocusCount: Int,
        focusStreak: Int
    ) {
        self.phase = phase
        self.state = state
        self.remaining = remaining
        self.lastRoundedRemaining = Int(ceil(remaining))
        self.todayFocusCount = todayFocusCount
        self.focusStreak = focusStreak
        self.endDate = nil
    }
}
