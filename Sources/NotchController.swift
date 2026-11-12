import AppKit
import QuartzCore
import SwiftUI

final class NotchController: NSObject, NSMenuDelegate {
    private let model: AppModel
    private let ui = NotchUIState()
    private var geometry: NotchGeometry

    var onOpenSettings: (() -> Void)?

    private var capPanel: NotchPanel!
    private var bodyPanel: NotchPanel!
    private var capInteraction: NotchInteractionView?
    private var bodyInteraction: NotchInteractionView?

    private var expandWork: DispatchWorkItem?
    private var collapseWork: DispatchWorkItem?
    private var hideWork: DispatchWorkItem?
    private var revealWork: DispatchWorkItem?
    private var screenWork: DispatchWorkItem?
    private var reminderDismissWork: DispatchWorkItem?

    private var capHovered = false
    private var bodyHovered = false
    private var isMenuOpen = false
    private var settingsOpen = false
    private var pendingReminderPhase: PomodoroPhase?

    private static let capLevel = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
    private static let bodyLevel = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue - 1)

    init?(model: AppModel) {
        guard let geometry = NotchGeometry.current() else { return nil }
        self.model = model
        self.geometry = geometry
        super.init()
        buildPanels()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(panelKeyChanged),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(panelKeyChanged),
            name: NSWindow.didResignKeyNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        expandWork?.cancel()
        collapseWork?.cancel()
        hideWork?.cancel()
        revealWork?.cancel()
        screenWork?.cancel()
        reminderDismissWork?.cancel()
    }

    // MARK: - 构建

    private func buildPanels() {
        ui.expanded = false
        ui.reminder = false
        capHovered = false
        bodyHovered = false
        isMenuOpen = false

        let capSize = geometry.capFrame.size
        let capContainer = NSView(frame: NSRect(origin: .zero, size: capSize))
        let capHost = NSHostingView(rootView: NotchRimView(model: model, pomodoro: model.pomodoro, ui: ui, geometry: geometry))
        capHost.frame = capContainer.bounds
        capHost.autoresizingMask = [.width, .height]
        capContainer.addSubview(capHost)

        let capInteraction = NotchInteractionView(frame: capContainer.bounds)
        capInteraction.kind = .cap
        capInteraction.controller = self
        capInteraction.autoresizingMask = [.width, .height]
        capInteraction.clickArea = capInteraction.bounds
        capInteraction.hoverArea = capInteraction.bounds
        capContainer.addSubview(capInteraction)

        let cap = NotchPanel(frame: geometry.capFrame, level: Self.capLevel)
        cap.contentView = capContainer
        capPanel = cap
        self.capInteraction = capInteraction
        cap.orderFrontRegardless()

        let bodySize = geometry.bodyWindowFrame(reminder: false).size
        let bodyContainer = NSView(frame: NSRect(origin: .zero, size: bodySize))

        let bodyHost = NSHostingView(
            rootView: NotchBodyView(
                model: model,
                pomodoro: model.pomodoro,
                theme: model.theme,
                ui: ui,
                geometry: geometry,
                onOpenSettings: { [weak self] in self?.onOpenSettings?() },
                onDismissReminder: { [weak self] in self?.dismissReminder() }
            )
        )
        bodyHost.frame = bodyContainer.bounds
        bodyHost.autoresizingMask = [.width, .height]
        bodyContainer.addSubview(bodyHost)

        let bodyInteraction = NotchInteractionView(frame: bodyContainer.bounds)
        bodyInteraction.kind = .body
        bodyInteraction.controller = self
        bodyInteraction.autoresizingMask = [.width, .height]
        bodyInteraction.hoverArea = geometry.bodyHoverRect(reminder: false)
        bodyInteraction.menuZone = geometry.timerMenuZone(reminder: false)
        bodyInteraction.clickArea = geometry.timerCardRect(reminder: false)
        bodyContainer.addSubview(bodyInteraction)

        let body = NotchPanel(frame: geometry.bodyWindowFrame(reminder: false), level: Self.bodyLevel)
        body.allowsKey = true
        body.keyClickRect = geometry.memoCardRect
        body.becomesKeyOnlyIfNeeded = true
        body.contentView = bodyContainer
        bodyPanel = body
        self.bodyInteraction = bodyInteraction
        body.ignoresMouseEvents = true
        body.orderOut(nil)
    }

    private func updateInteractionAreas() {
        guard let bodyInteraction else { return }
        let reminder = ui.reminder
        let menuZone = geometry.timerMenuZone(reminder: reminder)
        bodyInteraction.hoverArea = geometry.bodyHoverRect(reminder: reminder)
        bodyInteraction.menuZone = menuZone
        bodyInteraction.clickArea = geometry.timerCardRect(reminder: reminder)
        bodyInteraction.actionZones = controlZones(reminder: reminder)
        bodyPanel.keyClickRect = reminder ? .zero : geometry.memoCardRect
    }

    private func controlZones(reminder: Bool) -> [(rect: NSRect, action: () -> Void)] {
        var zones: [(rect: NSRect, action: () -> Void)] = [
            (geometry.timerPrimaryZone(reminder: reminder), { [weak self] in self?.primaryAction() }),
            (geometry.timerResetZone(reminder: reminder), { [weak self] in self?.resetAction() }),
            (geometry.timerSettingsZone(reminder: reminder), { [weak self] in self?.settingsAction() })
        ]
        if reminder, model.pomodoro.state == .completed {
            zones.append((geometry.timerLaterZone(reminder: reminder), { [weak self] in self?.laterAction() }))
        } else {
            zones.append((geometry.timerSkipZone(reminder: reminder), { [weak self] in self?.skipAction() }))
        }
        return zones
    }

    // MARK: - 悬停

    func hover(kind: NotchInteractionView.Kind, inside: Bool) {
        guard !settingsOpen else { return }
        switch kind {
        case .cap:
            capHovered = inside
            if inside {
                reminderDismissWork?.cancel()
                cancelCollapse()
                scheduleExpand()
            } else {
                expandWork?.cancel()
                scheduleCollapse()
            }
        case .body:
            bodyHovered = inside
            if inside {
                reminderDismissWork?.cancel()
                cancelCollapse()
                if !ui.expanded {
                    expand()
                }
            } else {
                scheduleCollapse()
            }
        }
    }

    private func scheduleExpand() {
        guard !settingsOpen else { return }
        expandWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.capHovered || self.bodyHovered else { return }
            self.expand()
        }
        expandWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }

    private func expand() {
        guard !settingsOpen, !ui.expanded else { return }
        expandWork?.cancel()
        cancelCollapse()
        bodyPanel.setFrame(geometry.bodyWindowFrame(reminder: ui.reminder), display: false)
        updateInteractionAreas()
        bodyPanel.ignoresMouseEvents = false
        bodyPanel.orderFrontRegardless()
        ui.expanded = true
    }

    private func scheduleCollapse() {
        guard ui.expanded else { return }
        guard !bodyPanel.isKeyWindow else { return }
        collapseWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard !self.isMenuOpen, !self.capHovered, !self.bodyHovered else { return }
            guard !self.bodyPanel.isKeyWindow else { return }
            self.startCollapse()
        }
        collapseWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32, execute: work)
    }

    private func startCollapse() {
        guard ui.expanded, !bodyPanel.isKeyWindow else { return }
        ui.expanded = false
        scheduleHide()
    }

    /// 用户点了「稍后」或开始下一阶段：即使面板是 key window 也收起。
    private func forceCollapse() {
        reminderDismissWork?.cancel()
        guard ui.expanded else {
            resetReminderIfNeeded()
            return
        }
        if bodyPanel.isKeyWindow {
            bodyPanel.makeFirstResponder(nil)
            bodyPanel.resignKey()
        }
        ui.expanded = false
        scheduleHide()
    }

    private func scheduleHide() {
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.ui.expanded else { return }
            self.bodyPanel.makeFirstResponder(nil)
            self.bodyPanel.ignoresMouseEvents = true
            self.bodyPanel.orderOut(nil)
            self.resetReminderIfNeeded()
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32, execute: work)
    }

    private func resetReminderIfNeeded() {
        guard ui.reminder else { return }
        ui.reminder = false
        bodyPanel.setFrame(geometry.bodyWindowFrame(reminder: false), display: false)
        updateInteractionAreas()
    }

    private func cancelCollapse() {
        collapseWork?.cancel()
        hideWork?.cancel()
    }

    /// 打开设置窗口前立即收起刘海面板，避免它挡在设置窗口上方。
    func hideForSettings() {
        settingsOpen = true
        reminderDismissWork?.cancel()
        expandWork?.cancel()
        collapseWork?.cancel()
        hideWork?.cancel()
        revealWork?.cancel()
        capHovered = false
        bodyHovered = false
        ui.expanded = false
        bodyPanel.makeFirstResponder(nil)
        bodyPanel.ignoresMouseEvents = true
        bodyPanel.orderOut(nil)
        resetReminderIfNeeded()
    }

    /// 设置窗口关闭后恢复刘海的悬停展开。
    func settingsDidClose() {
        settingsOpen = false
        if let phase = pendingReminderPhase {
            pendingReminderPhase = nil
            showReminder(phase: phase)
        }
    }

    /// 从 Finder 重新打开应用、或从菜单栏触发时，短暂展开。
    func revealTemporarily() {
        revealWork?.cancel()
        expand()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard !self.capHovered, !self.bodyHovered, !self.isMenuOpen else { return }
            self.startCollapse()
        }
        revealWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: work)
    }

    // MARK: - 到点提醒

    func showReminder(phase: PomodoroPhase) {
        if settingsOpen {
            pendingReminderPhase = phase
            return
        }
        reminderDismissWork?.cancel()
        revealWork?.cancel()
        expandWork?.cancel()
        cancelCollapse()

        if bodyPanel.isKeyWindow {
            bodyPanel.makeFirstResponder(nil)
            bodyPanel.resignKey()
        }

        if ui.reminder {
            // 已经处于提醒态，只确保它出现。
        } else if ui.expanded {
            ui.reminder = true
            animateBodyFrame(reminder: true)
            updateInteractionAreas()
        } else {
            ui.reminder = true
            bodyPanel.setFrame(geometry.bodyWindowFrame(reminder: true), display: false)
            updateInteractionAreas()
            bodyPanel.ignoresMouseEvents = false
            bodyPanel.orderFrontRegardless()
            ui.expanded = true
        }

        bodyPanel.ignoresMouseEvents = false
        bodyPanel.orderFrontRegardless()
        scheduleReminderAutoDismiss()

        // resignKey 触发的 didResignKey 可能安排了一次普通收起，这里再兜底取消，
        // 保证「时间到」的提醒至少完整出现。
        DispatchQueue.main.async { [weak self] in
            self?.cancelCollapse()
        }
    }

    private func animateBodyFrame(reminder: Bool) {
        let frame = geometry.bodyWindowFrame(reminder: reminder)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            bodyPanel.animator().setFrame(frame, display: true)
        }
    }

    private func scheduleReminderAutoDismiss() {
        reminderDismissWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard !self.capHovered, !self.bodyHovered, !self.isMenuOpen else { return }
            guard self.ui.reminder else { return }
            self.dismissReminder()
        }
        reminderDismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 20, execute: work)
    }

    private func dismissReminder() {
        guard ui.reminder else { return }
        forceCollapse()
    }

    // MARK: - 菜单

    func showMenu(with event: NSEvent, for view: NSView) {
        isMenuOpen = true
        reminderDismissWork?.cancel()
        collapseWork?.cancel()

        let menu = NSMenu()
        menu.delegate = self

        let header = NSMenuItem(
            title: "\(model.pomodoro.phase.title)  \(TimeFormat.countdown(model.pomodoro.remaining))",
            action: nil,
            keyEquivalent: ""
        )
        header.isEnabled = false
        header.attributedTitle = NSAttributedString(
            string: "\(model.pomodoro.phase.title)  \(TimeFormat.countdown(model.pomodoro.remaining))",
            attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)]
        )
        menu.addItem(header)

        let toggle = NSMenuItem(
            title: model.pomodoro.primaryActionTitle,
            action: #selector(togglePomodoro),
            keyEquivalent: ""
        )
        toggle.target = self
        menu.addItem(toggle)

        let reset = NSMenuItem(title: "重置本轮", action: #selector(resetPomodoro), keyEquivalent: "")
        reset.target = self
        menu.addItem(reset)

        let skip = NSMenuItem(title: "跳过本轮", action: #selector(skipPomodoro), keyEquivalent: "")
        skip.target = self
        menu.addItem(skip)

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "外观与计时设置…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let login = NSMenuItem(
            title: "登录时自动启动",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        login.target = self
        login.state = model.launchAtLogin ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())

        let today = NSMenuItem(
            title: "今日专注 \(model.pomodoro.todayFocusCount) 轮 · 使用 \(TimeFormat.human(model.todaySeconds))",
            action: nil,
            keyEquivalent: ""
        )
        today.isEnabled = false
        menu.addItem(today)

        let clearMemo = NSMenuItem(title: "清空备忘录…", action: #selector(clearMemoAction), keyEquivalent: "")
        clearMemo.target = self
        menu.addItem(clearMemo)

        let data = NSMenuItem(title: "打开数据文件夹", action: #selector(openDataFolder), keyEquivalent: "")
        data.target = self
        menu.addItem(data)

        let resetUsage = NSMenuItem(title: "重置使用统计…", action: #selector(resetStatistics), keyEquivalent: "")
        resetUsage.target = self
        menu.addItem(resetUsage)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "")
        quit.target = self
        menu.addItem(quit)

        NSMenu.popUpContextMenu(menu, with: event, for: view)

        if isMenuOpen {
            isMenuOpen = false
            if !capHovered && !bodyHovered {
                scheduleCollapse()
            }
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        isMenuOpen = true
        reminderDismissWork?.cancel()
    }

    func menuDidClose(_ menu: NSMenu) {
        isMenuOpen = false
        if !capHovered && !bodyHovered {
            scheduleCollapse()
        }
    }

    private func primaryAction() {
        let wasCompleted = model.pomodoro.state == .completed
        model.pomodoro.toggle()
        if wasCompleted, ui.reminder {
            dismissReminder()
        }
    }

    private func resetAction() {
        model.pomodoro.reset()
        if ui.reminder { dismissReminder() }
    }

    private func skipAction() {
        model.pomodoro.skip()
        if ui.reminder { dismissReminder() }
    }

    private func laterAction() {
        dismissReminder()
    }

    private func settingsAction() {
        onOpenSettings?()
    }

    @objc private func togglePomodoro() {
        primaryAction()
    }

    @objc private func resetPomodoro() {
        resetAction()
    }

    @objc private func skipPomodoro() {
        skipAction()
    }

    @objc private func openSettings() {
        settingsAction()
    }

    @objc private func toggleLaunchAtLogin() {
        model.launchAtLogin.toggle()
    }

    @objc private func resetStatistics() {
        model.confirmReset()
    }

    @objc private func clearMemoAction() {
        model.confirmClearMemo()
    }

    @objc private func openDataFolder() {
        model.openDataFolder()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func panelKeyChanged(_ notification: Notification) {
        guard let bodyPanel,
              let window = notification.object as? NSWindow,
              window === bodyPanel else { return }
        if window.isKeyWindow {
            reminderDismissWork?.cancel()
            cancelCollapse()
        } else if !capHovered && !bodyHovered && !isMenuOpen {
            scheduleCollapse()
        }
    }

    // MARK: - 屏幕变化

    @objc private func screenParametersChanged() {
        screenWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.rebuildForScreenChange()
        }
        screenWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: work)
    }

    private func rebuildForScreenChange() {
        guard let newGeometry = NotchGeometry.current() else { return }
        expandWork?.cancel()
        collapseWork?.cancel()
        hideWork?.cancel()
        revealWork?.cancel()
        reminderDismissWork?.cancel()
        capPanel?.orderOut(nil)
        bodyPanel?.orderOut(nil)
        capPanel = nil
        bodyPanel = nil
        capInteraction = nil
        bodyInteraction = nil
        geometry = newGeometry
        ui.expanded = false
        ui.reminder = false
        buildPanels()
    }
}

// MARK: - 无边框面板

private final class NotchPanel: NSPanel {
    var allowsKey = false
    /// 只有点击备忘录区域时才激活应用；点计时按钮不应抢走当前应用的焦点。
    var keyClickRect: NSRect = .zero

    override var canBecomeKey: Bool { allowsKey }
    override var canBecomeMain: Bool { false }

    init(frame: NSRect, level: NSWindow.Level) {
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = false
        becomesKeyOnlyIfNeeded = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovableByWindowBackground = false
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        self.level = level
    }

    /// 非激活面板收到第一次点击时，先激活应用并成为 key window，
    /// 再把事件交给正常的 hit-test，避免第一次点击被系统吞掉。
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown,
           allowsKey,
           !isKeyWindow,
           keyClickRect.contains(event.locationInWindow) {
            NSApp.activate(ignoringOtherApps: true)
            makeKey()
        }
        super.sendEvent(event)
    }

    // 允许窗口贴到屏幕最顶端、覆盖菜单栏，而不是被自动挤到菜单栏下方。
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}
