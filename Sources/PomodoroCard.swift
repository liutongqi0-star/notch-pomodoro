import SwiftUI

struct PomodoroCard: View {
    @ObservedObject var pomodoro: PomodoroEngine
    @ObservedObject var theme: ThemeModel
    let width: CGFloat
    let height: CGFloat
    var isReminder: Bool = false
    var onOpenSettings: () -> Void = {}
    var onDismissReminder: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Rectangle()
                .fill(Color.white.opacity(0.065))
                .frame(height: 1)
                .padding(.top, 7)
                .padding(.bottom, 8)

            center

            Spacer(minLength: 4)

            footer
        }
        .padding(.horizontal, 18)
        .padding(.top, 11)
        .padding(.bottom, 11)
        .frame(width: width, height: height, alignment: .topLeading)
        .background(ThemeCardBackground(theme: theme))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(ThemeCardBorder(glass: theme.glass))
        .overlay {
            if isReminder {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(accent.opacity(0.55), lineWidth: 1.3)
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeOut(duration: 0.22), value: pomodoro.state)
        .animation(.easeOut(duration: 0.22), value: pomodoro.phase)
    }

    // MARK: - 顶部

    private var header: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(accent)
                .frame(width: 6.5, height: 6.5)

            Text(pomodoro.phase.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.82))

            Text(pomodoro.stateTitle)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(
                    pomodoro.state == .completed
                        ? accent.opacity(0.95)
                        : Color.white.opacity(0.42)
                )

            Spacer(minLength: 6)

            Text(pomodoro.cycleTitle)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.44))
                .lineLimit(1)

            Button {
                onOpenSettings()
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.52))
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(Color.white.opacity(0.065)))
                    .contentShape(Circle())
            }
            .buttonStyle(PressableButtonStyle())
            .help("外观与计时设置")

            Image(systemName: "ellipsis")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.52))
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.white.opacity(0.065)))
                .accessibilityLabel("更多操作")
        }
        .frame(height: 18)
    }

    // MARK: - 中间倒计时

    private var center: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                if pomodoro.state == .completed {
                    Text(completionTitle)
                        .font(.system(size: 29, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                } else {
                    Text(TimeFormat.countdown(pomodoro.remaining))
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .contentTransition(.numericText(countsDown: true))
                }

                Text(pomodoro.subtitle)
                    .font(.system(size: 9.5, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.50))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .padding(.top, 1)
            }

            Spacer(minLength: 4)

            progressRing
        }
        .frame(height: 58)
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.085), lineWidth: 4)

            Circle()
                .trim(from: 0, to: max(0.001, pomodoro.progress))
                .stroke(
                    AngularGradient(
                        colors: [accent.opacity(0.55), accent, accent.opacity(0.9)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Image(systemName: pomodoro.state == .completed ? "checkmark" : pomodoro.phase.symbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(accent)
        }
        .frame(width: 54, height: 54)
        .accessibilityHidden(true)
    }

    // MARK: - 底部按钮

    private var footer: some View {
        HStack(spacing: 7) {
            Button {
                primaryAction()
            } label: {
                Text(pomodoro.primaryActionTitle)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Color(red: 0.08, green: 0.07, blue: 0.08))
                    .lineLimit(1)
                    .frame(width: 86, height: 26)
                    .background(
                        Capsule()
                            .fill(accent)
                    )
                    .contentShape(Capsule())
            }
            .buttonStyle(PressableButtonStyle())
            .help(pomodoro.primaryActionTitle)

            Button {
                pomodoro.reset()
                if isReminder { onDismissReminder() }
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.62))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.white.opacity(0.07)))
                    .contentShape(Circle())
            }
            .buttonStyle(PressableButtonStyle())
            .help("重置本轮")

            if pomodoro.state == .completed, isReminder {
                Button {
                    onDismissReminder()
                } label: {
                    Text("稍后")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.55))
                        .padding(.horizontal, 8)
                        .frame(height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
            } else {
                Button {
                    pomodoro.skip()
                    if isReminder { onDismissReminder() }
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.58))
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.white.opacity(0.07)))
                        .contentShape(Circle())
                }
                .buttonStyle(PressableButtonStyle())
                .help("跳过本轮")
            }

            Spacer(minLength: 4)

            Text(pomodoro.bottomHint)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.36))
                .lineLimit(1)
        }
        .frame(height: 26)
    }

    private func primaryAction() {
        let wasCompleted = pomodoro.state == .completed
        pomodoro.toggle()
        if wasCompleted, isReminder {
            onDismissReminder()
        }
    }

    // MARK: - 外观

    private var accent: Color {
        switch pomodoro.phase {
        case .focus:
            return Color(red: 1.00, green: 0.42, blue: 0.38)
        case .shortBreak:
            return Color(red: 0.36, green: 0.85, blue: 0.57)
        case .longBreak:
            return Color(red: 0.47, green: 0.66, blue: 1.00)
        }
    }

    private var completionTitle: String {
        pomodoro.phase == .focus ? "专注完成" : "休息结束"
    }
}

private struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.66 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
