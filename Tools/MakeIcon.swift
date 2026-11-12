import AppKit

// 生成 1024x1024 的 App 图标（番茄红渐变圆角方块 + 白色时钟）
let arguments = CommandLine.arguments
let outputPath = arguments.count > 1 ? arguments[1] : "icon-1024.png"
let size = 1024.0

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size),
    pixelsHigh: Int(size),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fatalError("无法创建位图")
}
rep.size = NSSize(width: size, height: size)

guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
    fatalError("无法创建绘图上下文")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.imageInterpolation = .high

NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: size, height: size).fill()

let inset: CGFloat = 58
let rect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let radius = rect.width * 0.235
let rounded = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

let background = NSGradient(colors: [
    NSColor(calibratedRed: 1.00, green: 0.42, blue: 0.34, alpha: 1.0),
    NSColor(calibratedRed: 0.80, green: 0.12, blue: 0.22, alpha: 1.0)
])!
background.draw(in: rounded, angle: -62)

let highlight = NSGradient(colors: [
    NSColor.white.withAlphaComponent(0.22),
    NSColor.white.withAlphaComponent(0.0)
])!
highlight.draw(in: rounded, angle: -90)

let innerBorder = NSBezierPath(
    roundedRect: rect.insetBy(dx: 3, dy: 3),
    xRadius: radius,
    yRadius: radius
)
innerBorder.lineWidth = 2
NSColor.white.withAlphaComponent(0.16).setStroke()
innerBorder.stroke()

let center = NSPoint(x: rect.midX, y: rect.midY)
let clockRadius: CGFloat = 246
let ringWidth: CGFloat = 40
let ringRect = NSRect(
    x: center.x - clockRadius,
    y: center.y - clockRadius,
    width: clockRadius * 2,
    height: clockRadius * 2
)
let ring = NSBezierPath(ovalIn: ringRect)
ring.lineWidth = ringWidth
NSColor.white.withAlphaComponent(0.94).setStroke()
ring.stroke()

func hand(angleDegrees: CGFloat, length: CGFloat, width: CGFloat, color: NSColor) {
    let radians = angleDegrees * .pi / 180
    let end = NSPoint(x: center.x + cos(radians) * length, y: center.y + sin(radians) * length)
    let path = NSBezierPath()
    path.move(to: center)
    path.line(to: end)
    path.lineWidth = width
    path.lineCapStyle = .round
    color.setStroke()
    path.stroke()
}

// 经典 10:10 造型
hand(angleDegrees: 148, length: 128, width: 32, color: NSColor.white)
hand(angleDegrees: 28, length: 182, width: 32, color: NSColor.white)
hand(angleDegrees: -24, length: 208, width: 14, color: NSColor(calibratedRed: 1.0, green: 0.84, blue: 0.42, alpha: 1.0))

let dotDiameter: CGFloat = 50
let dotRect = NSRect(
    x: center.x - dotDiameter / 2,
    y: center.y - dotDiameter / 2,
    width: dotDiameter,
    height: dotDiameter
)
let dot = NSBezierPath(ovalIn: dotRect)
NSColor.white.setFill()
dot.fill()

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("无法编码 PNG")
}
try png.write(to: URL(fileURLWithPath: outputPath))
print("图标已生成：\(outputPath)")
