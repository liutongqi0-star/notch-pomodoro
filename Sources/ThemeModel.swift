import AppKit
import Combine
import UniformTypeIdentifiers

enum GlassStyle: String, CaseIterable, Identifiable {
    case frosted
    case clear

    var id: String { rawValue }

    var title: String {
        switch self {
        case .frosted: return "毛玻璃"
        case .clear: return "透明玻璃"
        }
    }

    var detail: String {
        switch self {
        case .frosted: return "柔化背景，像一层磨砂玻璃"
        case .clear: return "保持清晰，能看见桌面与图片"
        }
    }

    var symbolName: String {
        switch self {
        case .frosted: return "circle.hexagongrid.fill"
        case .clear: return "square.on.square"
        }
    }
}

/// 面板背景主题：自定义图片 + 不透明度 + 玻璃质感。
final class ThemeModel: ObservableObject {
    @Published var opacity: Double = 0.72 {
        didSet {
            let value = min(max(opacity, 0.08), 1.0)
            if value != opacity {
                opacity = value
                return
            }
            if !previewMode {
                defaults.set(opacity, forKey: Keys.opacity)
            }
        }
    }

    @Published var glass: GlassStyle = .frosted {
        didSet {
            if !previewMode {
                defaults.set(glass.rawValue, forKey: Keys.glass)
            }
        }
    }

    @Published private(set) var image: NSImage?
    @Published private(set) var imageName: String?

    private enum Keys {
        static let opacity = "theme.opacity"
        static let glass = "theme.glass"
        static let imageFile = "theme.imageFile"
    }

    private let directory: URL
    private let defaults = UserDefaults.standard
    private let previewMode: Bool

    init(directory: URL) {
        self.directory = directory
        self.previewMode = ProcessInfo.processInfo.environment["USAGECLOCK_RENDER_PREVIEW"] == "1"

        let savedOpacity = defaults.object(forKey: Keys.opacity) as? Double ?? 0.72
        opacity = min(max(savedOpacity, 0.08), 1.0)
        glass = GlassStyle(rawValue: defaults.string(forKey: Keys.glass) ?? "") ?? .frosted

        if let name = defaults.string(forKey: Keys.imageFile) {
            let url = directory.appendingPathComponent(name, isDirectory: false)
            if let loaded = NSImage(contentsOf: url) {
                image = loaded
                imageName = name
            }
        }
    }

    // MARK: - 图片

    func chooseImage() {
        let panel = NSOpenPanel()
        panel.title = "选择板块背景图片"
        panel.message = "图片会复制到 UsageClock 的数据文件夹，不会修改原图。"
        panel.prompt = "使用图片"
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try importImage(from: url)
        } catch {
            presentError("无法使用这张图片", message: error.localizedDescription)
        }
    }

    func importImage(from url: URL) throws {
        guard let source = NSImage(contentsOf: url) else {
            throw ThemeError.unreadable
        }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // 限制到 2400px 内，避免把几十 MB 的原图塞进面板主题。
        let maxDimension: CGFloat = 2400
        let sourceSize = source.size
        guard sourceSize.width > 0, sourceSize.height > 0 else {
            throw ThemeError.unreadable
        }
        let scale = min(1, maxDimension / max(sourceSize.width, sourceSize.height))
        let target = NSSize(
            width: max(1, floor(sourceSize.width * scale)),
            height: max(1, floor(sourceSize.height * scale))
        )

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(target.width),
            pixelsHigh: Int(target.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw ThemeError.encodeFailed
        }
        rep.size = target

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
            throw ThemeError.encodeFailed
        }
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        source.draw(
            in: NSRect(origin: .zero, size: target),
            from: .zero,
            operation: .copy,
            fraction: 1
        )

        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw ThemeError.encodeFailed
        }

        let filename = "theme-image.png"
        let destination = directory.appendingPathComponent(filename, isDirectory: false)
        try data.write(to: destination, options: [.atomic])

        if let old = imageName, old != filename {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(old))
        }

        let hadImage = image != nil
        defaults.set(filename, forKey: Keys.imageFile)
        imageName = filename
        image = NSImage(data: data)

        // 第一次选择图片时把不透明度调高一点，避免桌面上的文字透过图片影响阅读。
        if !hadImage {
            opacity = max(opacity, 0.80)
        }
    }

    func removeImage() {
        if let name = imageName {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
        }
        defaults.removeObject(forKey: Keys.imageFile)
        imageName = nil
        image = nil
    }

    func resetAppearance() {
        removeImage()
        opacity = 0.72
        glass = .frosted
    }

    // MARK: - 展示图

    func applyPreview(image: NSImage?, opacity: Double, glass: GlassStyle) {
        self.image = image
        self.opacity = opacity
        self.glass = glass
    }

    private func presentError(_ title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "好")
        alert.runModal()
    }
}

private enum ThemeError: LocalizedError {
    case unreadable
    case encodeFailed

    var errorDescription: String? {
        switch self {
        case .unreadable:
            return "无法读取这张图片，请换一张 PNG、JPEG 或 HEIC 图片。"
        case .encodeFailed:
            return "图片处理失败，请换一张图片再试。"
        }
    }
}
