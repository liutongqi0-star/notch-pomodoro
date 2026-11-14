import Combine
import Foundation

/// 界面语言。`.system` 跟随系统首选语言，其余为应用内手动选择。
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case japanese = "ja"
    case korean = "ko"
    case spanish = "es"
    case french = "fr"
    case german = "de"

    var id: String { rawValue }

    /// 语言自己的写法，用于语言选择菜单，不随界面语言变化。
    var nativeName: String {
        switch self {
        case .system: return ""
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        case .traditionalChinese: return "繁體中文"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .system, .english: return "en"
        case .simplifiedChinese: return "zh_Hans"
        case .traditionalChinese: return "zh_Hant"
        case .japanese: return "ja_JP"
        case .korean: return "ko_KR"
        case .spanish: return "es_ES"
        case .french: return "fr_FR"
        case .german: return "de_DE"
        }
    }

    /// 系统首选语言里第一个受支持的语言。
    static func systemLanguage() -> AppLanguage {
        for identifier in Locale.preferredLanguages {
            let tag = identifier.lowercased()
            if tag.hasPrefix("zh") {
                if tag.contains("hant") || tag.contains("tw") || tag.contains("hk") || tag.contains("mo") {
                    return .traditionalChinese
                }
                return .simplifiedChinese
            }
            if tag.hasPrefix("ja") { return .japanese }
            if tag.hasPrefix("ko") { return .korean }
            if tag.hasPrefix("es") { return .spanish }
            if tag.hasPrefix("fr") { return .french }
            if tag.hasPrefix("de") { return .german }
            if tag.hasPrefix("en") { return .english }
        }
        return .english
    }
}

/// 应用内文案表。切换语言后立即通知 SwiftUI、菜单和窗口标题刷新。
final class L10n: ObservableObject {
    static let shared = L10n()
    static let languageDidChange = Notification.Name("UsageClock.languageDidChange")

    private(set) var selection: AppLanguage
    private(set) var resolved: AppLanguage

    private let defaults: UserDefaults
    private let lockedByEnvironment: Bool

    private static let defaultsKey = "app.language"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // 截图和自动化测试可以强制指定语言，不写入用户设置。
        if let raw = ProcessInfo.processInfo.environment["USAGECLOCK_LANGUAGE"],
           let language = AppLanguage(rawValue: raw),
           language != .system {
            selection = language
            resolved = language
            lockedByEnvironment = true
            return
        }

        lockedByEnvironment = false
        let saved = defaults.string(forKey: Self.defaultsKey)
            .flatMap(AppLanguage.init(rawValue:)) ?? .system
        selection = saved
        resolved = saved == .system ? AppLanguage.systemLanguage() : saved
    }

    func set(_ language: AppLanguage) {
        guard language != selection else {
            // 已经跟随系统时，再次选择「跟随系统」也要按当前系统语言刷新。
            guard language == .system else { return }
            let next = AppLanguage.systemLanguage()
            guard next != resolved else { return }
            resolved = next
            notifyChange()
            return
        }

        selection = language
        resolved = language == .system ? AppLanguage.systemLanguage() : language
        if !lockedByEnvironment {
            defaults.set(language.rawValue, forKey: Self.defaultsKey)
        }
        notifyChange()
    }

    /// 键缺失时回退到英文，最后才回退到键名。
    func t(_ key: String) -> String {
        if let value = L10nCatalog.tables[resolved.rawValue]?[key], !value.isEmpty {
            return value
        }
        if let value = L10nCatalog.tables[AppLanguage.english.rawValue]?[key] {
            return value
        }
        return key
    }

    /// 带格式参数的文案，例如 `f("cycle.roundOf", 2, 4)`。
    func f(_ key: String, _ arguments: CVarArg...) -> String {
        String(
            format: t(key),
            locale: Locale(identifier: resolved.localeIdentifier),
            arguments: arguments
        )
    }

    /// 语言选择菜单里的显示名；「跟随系统」带上当前解析到的语言。
    func label(for language: AppLanguage) -> String {
        if language == .system {
            return f("settings.languageSystemCurrent", resolved.nativeName)
        }
        return language.nativeName
    }

    private func notifyChange() {
        objectWillChange.send()
        NotificationCenter.default.post(name: Self.languageDidChange, object: self)
    }
}
