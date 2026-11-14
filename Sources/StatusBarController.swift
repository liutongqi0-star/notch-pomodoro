import AppKit
import Combine

final class StatusBarController: NSObject, NSMenuDelegate {
    private let model: AppModel
    private let statusItem: NSStatusItem
    private var cancellables = Set<AnyCancellable>()

    var onReveal: (() -> Void)?
    var onOpenSettings: (() -> Void)?

    init(model: AppModel) {
        self.model = model
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            button.imagePosition = .imageLeading
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        }

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        model.pomodoro.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.refreshTitle() }
            }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageChanged),
            name: L10n.languageDidChange,
            object: nil
        )

        refreshLocalizedChrome()
    }

    @objc private func languageChanged() {
        refreshLocalizedChrome()
    }

    private func refreshLocalizedChrome() {
        if let button = statusItem.button {
            let image = NSImage(
                systemSymbolName: "timer",
                accessibilityDescription: L10n.shared.t("menu.appName")
            )
            button.image = image?.withSymbolConfiguration(.init(pointSize: 12, weight: .medium))
            button.image?.isTemplate = true
            button.toolTip = L10n.shared.t("menu.appName")
        }
        refreshTitle()
    }

    private func refreshTitle() {
        let pomodoro = model.pomodoro
        statusItem.button?.title = " " + TimeFormat.countdown(pomodoro.remaining)
        statusItem.button?.toolTip = L10n.shared.f(
            "menu.status",
            "\(pomodoro.phase.title) \(TimeFormat.countdown(pomodoro.remaining))",
            pomodoro.todayFocusCount
        )
    }

    // MARK: - 菜单

    func menuWillOpen(_ menu: NSMenu) {
        rebuild(menu)
    }

    private func rebuild(_ menu: NSMenu) {
        menu.removeAllItems()

        let pomodoro = model.pomodoro
        let header = NSMenuItem()
        header.attributedTitle = NSAttributedString(
            string: "\(pomodoro.phase.title)  \(TimeFormat.countdown(pomodoro.remaining))",
            attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .semibold)]
        )
        header.isEnabled = false
        menu.addItem(header)

        let status = NSMenuItem(
            title: L10n.shared.f("menu.status", pomodoro.stateTitle, pomodoro.todayFocusCount),
            action: nil,
            keyEquivalent: ""
        )
        status.isEnabled = false
        menu.addItem(status)

        menu.addItem(.separator())

        let toggle = NSMenuItem(
            title: pomodoro.primaryActionTitle,
            action: #selector(togglePomodoro),
            keyEquivalent: ""
        )
        toggle.target = self
        menu.addItem(toggle)

        let reset = NSMenuItem(title: L10n.shared.t("menu.reset"), action: #selector(resetPomodoro), keyEquivalent: "")
        reset.target = self
        menu.addItem(reset)

        let skip = NSMenuItem(title: L10n.shared.t("menu.skip"), action: #selector(skipPomodoro), keyEquivalent: "")
        skip.target = self
        menu.addItem(skip)

        menu.addItem(.separator())

        let settings = NSMenuItem(title: L10n.shared.t("menu.settings"), action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let reveal = NSMenuItem(title: L10n.shared.t("menu.reveal"), action: #selector(revealPanel), keyEquivalent: "")
        reveal.target = self
        menu.addItem(reveal)

        menu.addItem(toggleItem(
            title: L10n.shared.t("menu.launchAtLogin"),
            isOn: model.launchAtLogin,
            action: #selector(toggleLaunchAtLogin)
        ))

        menu.addItem(.separator())

        let usage = NSMenuItem(
            title: L10n.shared.f(
                "menu.usage",
                TimeFormat.human(model.todaySeconds),
                TimeFormat.human(model.totalSeconds)
            ),
            action: nil,
            keyEquivalent: ""
        )
        usage.isEnabled = false
        menu.addItem(usage)

        let clearMemo = NSMenuItem(title: L10n.shared.t("menu.clearMemo"), action: #selector(clearMemoAction), keyEquivalent: "")
        clearMemo.target = self
        menu.addItem(clearMemo)

        let openData = NSMenuItem(title: L10n.shared.t("menu.openData"), action: #selector(openDataFolder), keyEquivalent: "")
        openData.target = self
        menu.addItem(openData)

        let resetUsage = NSMenuItem(title: L10n.shared.t("menu.resetUsage"), action: #selector(resetStatistics), keyEquivalent: "")
        resetUsage.target = self
        menu.addItem(resetUsage)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: L10n.shared.t("menu.quit"), action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    private func toggleItem(title: String, isOn: Bool, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.state = isOn ? .on : .off
        return item
    }

    // MARK: - 动作

    @objc private func togglePomodoro() {
        model.pomodoro.toggle()
    }

    @objc private func resetPomodoro() {
        model.pomodoro.reset()
    }

    @objc private func skipPomodoro() {
        model.pomodoro.skip()
    }

    @objc private func openSettings() {
        onOpenSettings?()
    }

    @objc private func revealPanel() {
        onReveal?()
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
}
