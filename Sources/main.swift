import AppKit
import SwiftUI

// MARK: - 展示图背景

private struct PreviewWallpaper: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.055, green: 0.075, blue: 0.12),
                    Color(red: 0.08, green: 0.12, blue: 0.20),
                    Color(red: 0.12, green: 0.09, blue: 0.17)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.98, green: 0.44, blue: 0.30).opacity(0.55),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 280
                    )
                )
                .frame(width: 560, height: 560)
                .offset(x: -210, y: 120)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.26, green: 0.66, blue: 1.0).opacity(0.42),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 320
                    )
                )
                .frame(width: 640, height: 640)
                .offset(x: 240, y: -80)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.56, green: 0.36, blue: 0.96).opacity(0.30),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 220
                    )
                )
                .frame(width: 440, height: 440)
                .offset(x: 70, y: 280)

            VStack(spacing: 0) {
                Color.black.opacity(0.16)
                    .frame(height: 32)
                Rectangle()
                    .fill(Color.white.opacity(0.055))
                    .frame(height: 1)
                Spacer(minLength: 0)
            }
        }
    }
}

private struct PreviewStage<Content: View>: View {
    let size: CGSize
    let bodyOffset: CGFloat
    let content: Content

    init(size: CGSize, bodyOffset: CGFloat, @ViewBuilder content: () -> Content) {
        self.size = size
        self.bodyOffset = bodyOffset
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .top) {
            PreviewWallpaper()
                .frame(width: size.width, height: size.height)
                .clipped()
            content
                .offset(y: bodyOffset)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }
}

// MARK: - 渲染

@MainActor
private func renderPreview() {
    guard let geometry = NotchGeometry.current() else { exit(1) }
    let model = AppModel()
    model.applyPreviewValues(total: 20_520, today: 8_280, session: 92)

    let wallpaper = makeWallpaperImage()
    model.theme.applyPreview(image: wallpaper, opacity: 0.82, glass: .frosted)
    model.pomodoro.applyPreview(
        phase: .focus,
        state: .running,
        remaining: 18 * 60 + 42,
        todayFocusCount: 3,
        focusStreak: 2
    )

    let ui = NotchUIState()
    ui.expanded = true

    let outputDirectory = ProcessInfo.processInfo.environment["USAGECLOCK_PREVIEW_DIR"] ?? "."

    let collapsed = PreviewStage(size: CGSize(width: 360, height: 90), bodyOffset: 0) {
        NotchRimView(model: model, ui: NotchUIState(), geometry: geometry)
            .frame(width: geometry.capWidth, height: geometry.capHeight)
    }
    render(collapsed, width: 360, height: 90, to: "\(outputDirectory)/preview-cap.png")

    let expandedHeight = 32 + geometry.bodyWindowHeight
    let expanded = PreviewStage(size: CGSize(width: 360, height: expandedHeight), bodyOffset: 32) {
        ZStack(alignment: .top) {
            NotchBodyView(
                model: model,
                pomodoro: model.pomodoro,
                theme: model.theme,
                ui: ui,
                geometry: geometry
            )
            .frame(width: geometry.bodyWindowWidth, height: geometry.bodyWindowHeight)

            NotchRimView(model: model, ui: ui, geometry: geometry)
                .frame(width: geometry.capWidth, height: geometry.capHeight)
                .offset(y: -32)
        }
    }
    render(expanded, width: 360, height: expandedHeight, to: "\(outputDirectory)/preview-body.png")

    model.pomodoro.applyPreview(
        phase: .focus,
        state: .completed,
        remaining: 0,
        todayFocusCount: 3,
        focusStreak: 3
    )
    ui.reminder = true
    let reminderHeight = 32 + geometry.reminderWindowHeight + 26
    let reminder = PreviewStage(size: CGSize(width: 360, height: reminderHeight), bodyOffset: 32) {
        ZStack(alignment: .top) {
            NotchBodyView(
                model: model,
                pomodoro: model.pomodoro,
                theme: model.theme,
                ui: ui,
                geometry: geometry
            )
            .frame(width: geometry.bodyWindowWidth, height: geometry.reminderWindowHeight)

            NotchRimView(model: model, ui: ui, geometry: geometry)
                .frame(width: geometry.capWidth, height: geometry.capHeight)
                .offset(y: -32)
        }
    }
    render(reminder, width: 360, height: reminderHeight, to: "\(outputDirectory)/preview-reminder.png")

    exit(0)
}

@MainActor
private func makeWallpaperImage() -> NSImage? {
    let renderer = ImageRenderer(content: PreviewWallpaper().frame(width: 1200, height: 800))
    renderer.scale = 1
    guard let cgImage = renderer.cgImage else { return nil }
    return NSImage(cgImage: cgImage, size: NSSize(width: 1200, height: 800))
}

@MainActor
private func render<V: View>(_ view: V, width: CGFloat, height: CGFloat, to path: String) {
    let renderer = ImageRenderer(content: view.frame(width: width, height: height))
    renderer.scale = 2
    renderer.isOpaque = true
    guard let cgImage = renderer.cgImage else {
        FileHandle.standardError.write(Data("render failed: \(path)\n".utf8))
        return
    }
    let rep = NSBitmapImageRep(cgImage: cgImage)
    guard let data = rep.representation(using: .png, properties: [:]) else { return }
    try? data.write(to: URL(fileURLWithPath: path))
    print("rendered \(path)")
}

if ProcessInfo.processInfo.environment["USAGECLOCK_RENDER_PREVIEW"] == "1" {
    NSApplication.shared.setActivationPolicy(.prohibited)
    MainActor.assumeIsolated { renderPreview() }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
