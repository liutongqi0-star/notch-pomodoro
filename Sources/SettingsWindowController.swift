import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    var onClose: (() -> Void)?

    init(model: AppModel) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 470, height: 720),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.shared.t("settings.title")
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.collectionBehavior = [.moveToActiveSpace]
        window.backgroundColor = .windowBackgroundColor
        window.isOpaque = true
        if ProcessInfo.processInfo.environment["USAGECLOCK_DARK"] == "1" {
            window.appearance = NSAppearance(named: .darkAqua)
        }

        let root = SettingsView(
            model: model,
            pomodoro: model.pomodoro,
            theme: model.theme,
            onClose: { [weak window] in
                window?.performClose(nil)
            }
        )
        window.contentViewController = NSHostingController(rootView: root)
        window.setContentSize(NSSize(width: 470, height: 720))
        super.init(window: window)
        shouldCascadeWindows = false
        window.delegate = self

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageChanged),
            name: L10n.languageDidChange,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func languageChanged() {
        window?.title = L10n.shared.t("settings.title")
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }

    func show() {
        guard let window else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.setContentSize(NSSize(width: 470, height: 720))
        window.makeKeyAndOrderFront(nil)

        let screen = window.screen ?? NSScreen.main ?? NSScreen.screens.first
        if let visible = screen?.visibleFrame {
            let size = window.frame.size
            let x = visible.midX - size.width / 2
            let y = visible.midY - size.height / 2
            window.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
        }
    }
}
