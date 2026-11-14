import Foundation

enum TimeFormat {
    /// 00:00:00 风格的时长，用于小窗主数字
    static func clock(_ seconds: Double) -> String {
        let total = max(0, Int(seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }


    /// 番茄钟倒计时：25:00；超过一小时时显示 1:25:00
    static func countdown(_ seconds: Double) -> String {
        let total = max(0, Int(ceil(seconds)))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }

    /// 菜单栏里的紧凑格式，例如 3:07、47m
    static func menuBar(_ seconds: Double) -> String {
        let total = max(0, Int(seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return String(format: "%d:%02d", h, m) }
        return "\(m)m"
    }

    /// 只显示整小时，例如「5 小时」
    static func hoursOnly(_ seconds: Double) -> String {
        let hours = max(0, Int(seconds)) / 3600
        return "\(hours)h"
    }

    /// 小时:分钟，不含秒，例如「2:18」
    static func hourMinute(_ seconds: Double) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%d:%02d", total / 3600, (total % 3600) / 60)
    }

    /// 自然语言格式，例如「3 小时 7 分」
    static func human(_ seconds: Double) -> String {
        let total = max(0, Int(seconds))
        if total < 60 { return L10n.shared.f("time.seconds", total) }
        let h = total / 3600
        let m = (total % 3600) / 60
        if h == 0 { return L10n.shared.f("time.minutes", m) }
        if m == 0 { return L10n.shared.f("time.hours", h) }
        return L10n.shared.f("time.hoursMinutes", h, m)
    }

    /// 本地时区下的日期键，例如 2026-10-19
    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
    }
}
