import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    private var statusBar: StatusBarController?
    private var notch: NotchController?
    private lazy var settingsWindow = SettingsWindowController(model: model)

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBar = StatusBarController(model: model)
        notch = NotchController(model: model)

        statusBar?.onReveal = { [weak notch] in
            notch?.revealTemporarily()
        }
        statusBar?.onOpenSettings = { [weak self] in
            self?.openSettings()
        }
        notch?.onOpenSettings = { [weak self] in
            self?.openSettings()
        }
        settingsWindow.onClose = { [weak notch] in
            notch?.settingsDidClose()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(pomodoroPhaseCompleted(_:)),
            name: .pomodoroPhaseCompleted,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(saveBeforeTermination),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        notch?.revealTemporarily()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.persistNow()
    }

    @objc private func openSettings() {
        notch?.hideForSettings()
        settingsWindow.show()
    }

    @objc private func pomodoroPhaseCompleted(_ notification: Notification) {
        guard let raw = notification.userInfo?["phase"] as? String,
              let phase = PomodoroPhase(rawValue: raw) else { return }
        notch?.showReminder(phase: phase)
    }

    @objc private func saveBeforeTermination() {
        model.persistNow()
    }
}
