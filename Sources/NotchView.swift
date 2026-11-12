import SwiftUI

final class NotchUIState: ObservableObject {
    @Published var expanded = false
    @Published var reminder = false
}

enum RainbowPalette {
    static let colors: [Color] = [
        Color(red: 1.00, green: 0.26, blue: 0.32),
        Color(red: 1.00, green: 0.58, blue: 0.20),
        Color(red: 1.00, green: 0.86, blue: 0.24),
        Color(red: 0.34, green: 0.87, blue: 0.43),
        Color(red: 0.20, green: 0.80, blue: 0.95),
        Color(red: 0.25, green: 0.46, blue: 1.00),
        Color(red: 0.64, green: 0.33, blue: 1.00),
        Color(red: 1.00, green: 0.26, blue: 0.32)
    ]

    /// 进度条模式去掉末尾重复的红色，让整条 U 从左到右呈现完整色谱。
    static let progressColors = Array(colors.dropLast())
}

// MARK: - 环绕刘海的彩虹

struct NotchRimView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var pomodoro: PomodoroEngine
    @ObservedObject var ui: NotchUIState
    let geometry: NotchGeometry

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !model.isActive)) { timeline in
            Canvas { context, _ in
                draw(
                    context: &context,
                    time: timeline.date.timeIntervalSinceReferenceDate
                )
            }
        }
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.25), value: ui.expanded)
    }

    private func draw(context: inout GraphicsContext, time: TimeInterval) {
        let notch = geometry.notchRectInCap
        let inset: CGFloat = 1.4
        let rect = CGRect(
            x: notch.minX - inset,
            y: -2,
            width: notch.width + inset * 2,
            height: notch.height + inset + 2
        )
        let radius: CGFloat = 11
        let rim = Self.openUPath(in: rect, radius: radius)
        let pulse = ui.reminder
            ? 0.88 + 0.12 * CGFloat(sin(time * 4.2))
            : 1

        if pomodoro.state != .ready {
            drawProgress(context: &context, rim: rim, rect: rect, pulse: pulse)
            return
        }

        if !geometry.hasNotch {
            let silhouetteRect = CGRect(
                x: notch.minX,
                y: -2,
                width: notch.width,
                height: notch.height + 2
            )
            context.fill(
                Self.closedNotchPath(in: silhouetteRect, radius: radius),
                with: .color(.black)
            )
        }

        let phase = CGFloat(
            time.truncatingRemainder(dividingBy: 2.8) / 2.8
        )
        let h = rect.height + 10
        let startY = rect.minY - h + phase * h
        let endY = rect.maxY + h + phase * h
        let verticalShading = GraphicsContext.Shading.linearGradient(
            Gradient(colors: RainbowPalette.colors + RainbowPalette.colors),
            startPoint: CGPoint(x: rect.midX, y: startY),
            endPoint: CGPoint(x: rect.midX, y: endY)
        )

        // 下方柔和的彩色水雾
        let mistHeight: CGFloat = ui.expanded ? 16 : 11
        let mist = CGRect(
            x: rect.minX + 14,
            y: rect.maxY - 2,
            width: rect.width - 28,
            height: mistHeight
        )
        let mistPhase = CGFloat(
            time.truncatingRemainder(dividingBy: 3.2) / 3.2
        )
        let mistStart = mist.minX - mist.width + mistPhase * mist.width
        let mistEnd = mist.minX + mist.width + mistPhase * mist.width
        let horizontalShading = GraphicsContext.Shading.linearGradient(
            Gradient(colors: RainbowPalette.colors + RainbowPalette.colors),
            startPoint: CGPoint(x: mistStart, y: mist.midY),
            endPoint: CGPoint(x: mistEnd, y: mist.midY)
        )
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 8))
            layer.opacity = (ui.expanded ? 0.55 : 0.42) * pulse
            layer.fill(
                Path(roundedRect: mist, cornerRadius: mistHeight / 2),
                with: horizontalShading
            )
        }

        // 外发光
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: ui.expanded ? 6 : 4.5))
            layer.opacity = (ui.expanded ? 0.95 : 0.8) * pulse
            layer.stroke(
                rim,
                with: verticalShading,
                style: StrokeStyle(
                    lineWidth: ui.expanded ? 9 : 7,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }

        // 主彩虹线
        context.stroke(
            rim,
            with: verticalShading,
            style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)
        )

        // 底边横向流动的高光
        let bottom = Self.bottomPath(in: rect, radius: radius)
        let w = rect.width
        let shimmerStart = rect.minX - w + phase * w
        let shimmerEnd = rect.minX + w + phase * w
        let shimmer = GraphicsContext.Shading.linearGradient(
            Gradient(colors: RainbowPalette.colors + RainbowPalette.colors),
            startPoint: CGPoint(x: shimmerStart, y: rect.maxY),
            endPoint: CGPoint(x: shimmerEnd, y: rect.maxY)
        )
        context.drawLayer { layer in
            layer.opacity = 0.9 * pulse
            layer.stroke(
                bottom,
                with: shimmer,
                style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
            )
        }
    }

    /// 倒计时期间，彩虹不再是流动的光环，而是沿 U 形路径从左到右填充的进度条。
    /// 0% 完全不画彩虹，100% 画满整条 U。
    private func drawProgress(
        context: inout GraphicsContext,
        rim: Path,
        rect: CGRect,
        pulse: CGFloat
    ) {
        let progress = min(max(pomodoro.liveProgress, 0), 1)
        guard progress > 0.0005 else { return }

        let filled = rim.trimmedPath(from: 0, to: progress)
        let shading = GraphicsContext.Shading.linearGradient(
            Gradient(colors: RainbowPalette.progressColors),
            startPoint: CGPoint(x: rect.minX, y: rect.midY),
            endPoint: CGPoint(x: rect.maxX, y: rect.midY)
        )

        // 填充部分的外发光
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: ui.expanded ? 7.5 : 5.5))
            layer.opacity = 0.9 * pulse
            layer.stroke(
                filled,
                with: shading,
                style: StrokeStyle(
                    lineWidth: ui.expanded ? 8.5 : 7,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }

        // 彩虹进度条本体
        context.stroke(
            filled,
            with: shading,
            style: StrokeStyle(
                lineWidth: ui.expanded ? 3.2 : 2.8,
                lineCap: .round,
                lineJoin: .round
            )
        )
    }

    private static func openUPath(in rect: CGRect, radius: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.maxY),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY - radius),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }

    private static func closedNotchPath(in rect: CGRect, radius: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.maxY),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY - radius),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }

    private static func bottomPath(in rect: CGRect, radius: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.maxY),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY - radius),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        return path
    }
}

// MARK: - 展开卡片

struct NotchBodyView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var pomodoro: PomodoroEngine
    @ObservedObject var theme: ThemeModel
    @ObservedObject var ui: NotchUIState
    let geometry: NotchGeometry
    var onOpenSettings: () -> Void = {}
    var onDismissReminder: () -> Void = {}

    var body: some View {
        ZStack(alignment: .top) {
            neck

            VStack(spacing: geometry.memoGap) {
                PomodoroCard(
                    pomodoro: pomodoro,
                    theme: theme,
                    width: geometry.bodyWidth,
                    height: geometry.timerHeight,
                    isReminder: ui.reminder,
                    onOpenSettings: onOpenSettings,
                    onDismissReminder: onDismissReminder
                )

                if !ui.reminder {
                    memoCard
                        .transition(.opacity)
                }
            }
            .offset(y: geometry.bodyTopInset)
        }
        .frame(width: geometry.bodyWindowWidth, height: contentHeight, alignment: .top)
        .opacity(ui.expanded ? 1 : 0)
        .offset(y: ui.expanded ? 0 : -8)
        .scaleEffect(ui.expanded ? 1 : 0.99, anchor: .top)
        .animation(.spring(response: 0.4, dampingFraction: 0.86), value: ui.expanded)
        .animation(.easeInOut(duration: 0.22), value: ui.reminder)
    }

    private var contentHeight: CGFloat {
        ui.reminder ? geometry.reminderWindowHeight : geometry.bodyWindowHeight
    }

    private var neck: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: 10,
            bottomTrailingRadius: 10,
            topTrailingRadius: 0,
            style: .continuous
        )
        .fill(Color.black)
        .frame(width: geometry.notchWidth, height: 22)
    }

    // MARK: 备忘录卡片

    private var memoCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.56))

                Text("想法备忘录")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.56))

                Spacer(minLength: 8)

                Text("自动保存")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.32))
            }

            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)
                .padding(.top, 8)
                .padding(.bottom, 8)

            memoBody
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 14)
        .frame(width: geometry.bodyWidth, height: geometry.memoHeight, alignment: .topLeading)
        .background(ThemeCardBackground(theme: theme))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(ThemeCardBorder(glass: theme.glass))
    }

    private var memoBody: some View {
        ZStack(alignment: .topLeading) {
            if isPreview {
                Text("灵感随手记下来，\n回头再整理成清单。")
                    .font(.system(size: 13.5))
                    .lineSpacing(5)
                    .foregroundStyle(Color.white.opacity(0.72))
                    .padding(.top, 3)
            } else {
                MemoEditor(text: $model.memoText)

                if model.memoText.isEmpty {
                    Text("随手记下想法…")
                        .font(.system(size: 13.5))
                        .foregroundStyle(Color.white.opacity(0.36))
                        .padding(.top, 3)
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["USAGECLOCK_RENDER_PREVIEW"] == "1"
    }
}
