import AppKit

/// 覆盖在刘海界面上的透明交互层：负责悬停和右键/⋯ 菜单。
final class NotchInteractionView: NSView {
    enum Kind {
        case cap
        case body
    }

    weak var controller: NotchController?
    var kind: Kind = .body

    /// 拦截点击的区域（例如卡片顶部；备忘录区域留空以便输入）
    var clickArea: NSRect = .zero {
        didSet {
            guard clickArea != oldValue else { return }
            window?.invalidateCursorRects(for: self)
        }
    }

    /// 悬停保持区域（覆盖时钟卡片和备忘录）
    var hoverArea: NSRect = .zero {
        didSet {
            guard hoverArea != oldValue else { return }
            rebuildTracking()
        }
    }

    /// 展开面板右上角 ⋯ 的点击区域
    var menuZone: NSRect = .zero

    /// 透明层上的按钮区域。按钮本身由 SwiftUI 绘制，点击由这里统一处理，
    /// 这样非激活面板的第一次点击也不会被系统吞掉。
    var actionZones: [(rect: NSRect, action: () -> Void)] = [] {
        didSet { window?.invalidateCursorRects(for: self) }
    }

    private var tracking: NSTrackingArea?
    private var isUpdatingTracking = false

    override var acceptsFirstResponder: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard clickArea.contains(point) else { return nil }
        return self
    }

    override func resetCursorRects() {
        switch kind {
        case .cap:
            if clickArea.width > 1 {
                addCursorRect(clickArea, cursor: .pointingHand)
            }
        case .body:
            if menuZone.width > 1 {
                addCursorRect(menuZone, cursor: .pointingHand)
            }
            for zone in actionZones where zone.rect.width > 1 {
                addCursorRect(zone.rect, cursor: .pointingHand)
            }
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        guard !isUpdatingTracking else { return }
        isUpdatingTracking = true
        rebuildTracking()
        isUpdatingTracking = false
    }

    private func rebuildTracking() {
        if let tracking {
            removeTrackingArea(tracking)
            self.tracking = nil
        }
        guard hoverArea.width > 1, hoverArea.height > 1 else { return }
        let area = NSTrackingArea(
            rect: hoverArea,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) {
        controller?.hover(kind: kind, inside: true)
    }

    override func mouseExited(with event: NSEvent) {
        controller?.hover(kind: kind, inside: false)
    }

    override func mouseDown(with event: NSEvent) {
        guard kind == .body else { return }
        let point = convert(event.locationInWindow, from: nil)
        if menuZone.contains(point) {
            controller?.showMenu(with: event, for: self)
            return
        }
        for zone in actionZones where zone.rect.contains(point) {
            zone.action()
            return
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        controller?.showMenu(with: event, for: self)
    }
}
