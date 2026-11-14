import Foundation

/// 通过用户级 LaunchAgent 实现「登录时自动启动」。
/// 不写入系统目录，不需要管理员权限，也不会出现在 Dock。
enum LoginItem {
    static let label = "com.dumaster.usageclock"

    static var launchAgentsDirectory: URL {
        if let override = ProcessInfo.processInfo.environment["USAGECLOCK_AGENT_DIR"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
    }

    static var plistURL: URL {
        launchAgentsDirectory.appendingPathComponent("\(label).plist")
    }

    static func isEnabled() -> Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            guard let executable = Bundle.main.executableURL else {
                throw NSError(domain: "UsageClock", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: L10n.shared.t("alert.loginItemMissing")
                ])
            }
            try FileManager.default.createDirectory(at: launchAgentsDirectory, withIntermediateDirectories: true)
            let plist: [String: Any] = [
                "Label": label,
                "ProgramArguments": [executable.path],
                "RunAtLoad": true,
                "ProcessType": "Interactive"
            ]
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: plistURL, options: .atomic)
        } else {
            if FileManager.default.fileExists(atPath: plistURL.path) {
                try FileManager.default.removeItem(at: plistURL)
            }
        }
    }

    /// 应用被移动过位置时，把 LaunchAgent 里的可执行路径更新为当前位置。
    static func refreshIfEnabled() {
        guard isEnabled() else { return }
        do {
            try setEnabled(true)
        } catch {
            NSLog("UsageClock: failed to refresh login item: \(error.localizedDescription)")
        }
    }
}
