import AppKit

/// 刘海的位置和面板尺寸。
struct NotchGeometry {
    let screen: NSScreen
    let hasNotch: Bool
    let menuBarHeight: CGFloat
    let notchWidth: CGFloat
    let notchCenterX: CGFloat

    /// 环绕彩虹的窗口（刘海 + 左右/下方留白）
    let capWidth: CGFloat
    let capHeight: CGFloat

    /// 展开卡片（番茄钟 + 备忘录）
    let bodyWidth: CGFloat
    let timerHeight: CGFloat
    let memoHeight: CGFloat
    let memoGap: CGFloat
    let bodyHeight: CGFloat
    let reminderBodyHeight: CGFloat
    let bodyTopInset: CGFloat
    let bodyPadding: CGFloat
    let bodyWindowWidth: CGFloat
    let bodyWindowHeight: CGFloat
    let reminderWindowHeight: CGFloat

    static func current() -> NotchGeometry? {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return nil }

        let notched = screens.first {
            $0.auxiliaryTopLeftArea != nil && $0.auxiliaryTopRightArea != nil
        }
        let screen = notched ?? NSScreen.main ?? screens[0]

        let menuHeight = max(screen.safeAreaInsets.top, 24)
        var notchWidth: CGFloat = 180
        var centerX = screen.frame.midX
        var hasNotch = false

        if let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            let width = right.minX - left.maxX
            if width > 80 {
                hasNotch = true
                notchWidth = width
                centerX = (left.maxX + right.minX) / 2
            }
        }

        let capWidth = notchWidth + 28
        let capHeight = menuHeight + 18
        let bodyWidth = min(344, screen.frame.width - 100)
        let timerHeight: CGFloat = 168
        let memoHeight: CGFloat = 160
        let memoGap: CGFloat = 10
        let bodyHeight = timerHeight + memoGap + memoHeight
        let reminderBodyHeight = timerHeight
        let bodyTopInset: CGFloat = 6
        let bodyPadding: CGFloat = 8

        return NotchGeometry(
            screen: screen,
            hasNotch: hasNotch,
            menuBarHeight: menuHeight,
            notchWidth: notchWidth,
            notchCenterX: centerX,
            capWidth: capWidth,
            capHeight: capHeight,
            bodyWidth: bodyWidth,
            timerHeight: timerHeight,
            memoHeight: memoHeight,
            memoGap: memoGap,
            bodyHeight: bodyHeight,
            reminderBodyHeight: reminderBodyHeight,
            bodyTopInset: bodyTopInset,
            bodyPadding: bodyPadding,
            bodyWindowWidth: bodyWidth + bodyPadding * 2,
            bodyWindowHeight: bodyTopInset + bodyHeight + bodyPadding,
            reminderWindowHeight: bodyTopInset + reminderBodyHeight + bodyPadding
        )
    }

    /// 环绕彩虹的窗口，贴在屏幕最顶端
    var capFrame: NSRect {
        NSRect(
            x: notchCenterX - capWidth / 2,
            y: screen.frame.maxY - capHeight,
            width: capWidth,
            height: capHeight
        )
    }

    /// 展开卡片的窗口（顶部紧贴菜单栏下缘）。提醒时只保留番茄钟卡片的高度。
    func bodyWindowFrame(reminder: Bool) -> NSRect {
        let height = reminder ? reminderWindowHeight : bodyWindowHeight
        return NSRect(
            x: notchCenterX - bodyWindowWidth / 2,
            y: screen.frame.maxY - menuBarHeight - height,
            width: bodyWindowWidth,
            height: height
        )
    }

    var bodyWindowFrame: NSRect {
        bodyWindowFrame(reminder: false)
    }

    /// 番茄钟卡片在窗口里的区域（Cocoa 坐标，原点左下）。
    func timerCardRect(reminder: Bool) -> NSRect {
        let contentHeight = reminder ? reminderBodyHeight : bodyHeight
        return NSRect(
            x: (bodyWindowWidth - bodyWidth) / 2,
            y: bodyPadding + contentHeight - timerHeight,
            width: bodyWidth,
            height: timerHeight
        )
    }

    /// 备忘录卡片在窗口里的区域
    var memoCardRect: NSRect {
        NSRect(
            x: (bodyWindowWidth - bodyWidth) / 2,
            y: bodyPadding,
            width: bodyWidth,
            height: memoHeight
        )
    }

    /// 悬停保持区域：两张卡片 + 中间间距；提醒态只有番茄钟卡片。
    func bodyHoverRect(reminder: Bool) -> NSRect {
        if reminder {
            return timerCardRect(reminder: true)
        }
        return NSRect(
            x: (bodyWindowWidth - bodyWidth) / 2,
            y: bodyPadding,
            width: bodyWidth,
            height: bodyHeight
        )
    }

    /// 番茄钟底部按钮的点击区域。主按钮固定 86pt 宽，便于透明交互层精确命中。
    func timerPrimaryZone(reminder: Bool) -> NSRect {
        let card = timerCardRect(reminder: reminder)
        return NSRect(x: card.minX + 14, y: card.minY + 7, width: 94, height: 34)
    }

    func timerResetZone(reminder: Bool) -> NSRect {
        let card = timerCardRect(reminder: reminder)
        return NSRect(x: card.minX + 107, y: card.minY + 7, width: 34, height: 34)
    }

    func timerSkipZone(reminder: Bool) -> NSRect {
        let card = timerCardRect(reminder: reminder)
        return NSRect(x: card.minX + 140, y: card.minY + 7, width: 34, height: 34)
    }

    func timerLaterZone(reminder: Bool) -> NSRect {
        let card = timerCardRect(reminder: reminder)
        return NSRect(x: card.minX + 138, y: card.minY + 7, width: 52, height: 34)
    }

    /// 齿轮设置按钮
    func timerSettingsZone(reminder: Bool) -> NSRect {
        let card = timerCardRect(reminder: reminder)
        return NSRect(x: card.maxX - 68, y: card.maxY - 37, width: 30, height: 33)
    }

    /// 番茄钟卡片右上角 ⋯ 的点击区域
    func timerMenuZone(reminder: Bool) -> NSRect {
        let card = timerCardRect(reminder: reminder)
        return NSRect(
            x: card.maxX - 38,
            y: card.maxY - 36,
            width: 24,
            height: 27
        )
    }

    /// 彩虹条窗口内的刘海矩形（SwiftUI 顶左坐标）
    var notchRectInCap: CGRect {
        CGRect(
            x: (capWidth - notchWidth) / 2,
            y: 0,
            width: notchWidth,
            height: menuBarHeight
        )
    }
}
