import AppKit
import SwiftUI

// MARK: - 可主题化的卡片背景

struct ThemeCardBackground: View {
    @ObservedObject var theme: ThemeModel
    var cornerRadius: CGFloat = 24
    var simulated = false

    private var isPreview: Bool {
        simulated || ProcessInfo.processInfo.environment["USAGECLOCK_RENDER_PREVIEW"] == "1"
    }

    var body: some View {
        ZStack {
            if theme.glass == .frosted {
                simulatedFrost
            } else {
                Color.black.opacity(0.12)
            }

            Color.black.opacity(baseTint)

            if let image = theme.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .opacity(theme.opacity)
                    .blur(radius: theme.glass == .frosted ? (isPreview ? 7 : 11) : 0)
            }

            // 深色保护层：保证白字在明亮桌面或浅色图片上仍然清楚。
            LinearGradient(
                colors: [
                    Color.black.opacity(0.08),
                    Color.black.opacity(0.20),
                    Color.black.opacity(0.48)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // 顶部玻璃高光
            LinearGradient(
                colors: [Color.white.opacity(0.11), Color.white.opacity(0.0)],
                startPoint: .top,
                endPoint: .center
            )
            .blendMode(.plusLighter)
            .opacity(theme.glass == .clear ? 0.9 : 0.55)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var baseTint: Double {
        if isPreview { return 0.18 }
        return theme.glass == .clear
            ? 0.30 + 0.55 * theme.opacity
            : 0.10 + 0.42 * theme.opacity
    }

    private var simulatedFrost: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.20, blue: 0.34),
                    Color(red: 0.24, green: 0.12, blue: 0.30),
                    Color(red: 0.05, green: 0.09, blue: 0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(Color(red: 0.96, green: 0.54, blue: 0.38).opacity(0.55))
                .frame(width: 190, height: 190)
                .blur(radius: 60)
                .offset(x: -100, y: 40)
            Circle()
                .fill(Color(red: 0.35, green: 0.72, blue: 0.95).opacity(0.50))
                .frame(width: 170, height: 170)
                .blur(radius: 55)
                .offset(x: 105, y: -50)
        }
    }
}

struct ThemeCardBorder: View {
    let glass: GlassStyle
    var cornerRadius: CGFloat = 24

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(glass == .clear ? 0.30 : 0.17),
                        Color.white.opacity(0.055),
                        Color.white.opacity(glass == .clear ? 0.12 : 0.035)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )
            .overlay(alignment: .top) {
                Capsule()
                    .fill(Color.white.opacity(glass == .clear ? 0.30 : 0.14))
                    .frame(height: 1)
                    .padding(.horizontal, 30)
                    .padding(.top, 1)
            }
            .allowsHitTesting(false)
    }
}

// MARK: - 设置里的迷你预览

struct ThemePreviewCard: View {
    @ObservedObject var theme: ThemeModel

    var body: some View {
        Color.clear
            .frame(height: 108)
            .background {
                ZStack {
                    previewBackdrop
                    ThemeCardBackground(theme: theme, cornerRadius: 18, simulated: true)
                }
            }
            .overlay(alignment: .topLeading) {
                previewContent
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(ThemeCardBorder(glass: theme.glass, cornerRadius: 18))
    }

    private var previewBackdrop: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.18, green: 0.24, blue: 0.40),
                    Color(red: 0.42, green: 0.20, blue: 0.34),
                    Color(red: 0.10, green: 0.16, blue: 0.24)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(Color(red: 0.98, green: 0.48, blue: 0.32).opacity(0.60))
                .frame(width: 150, height: 150)
                .blur(radius: 50)
                .offset(x: -120, y: 20)
            Circle()
                .fill(Color(red: 0.30, green: 0.62, blue: 1.0).opacity(0.55))
                .frame(width: 170, height: 170)
                .blur(radius: 55)
                .offset(x: 130, y: -30)
        }
        .allowsHitTesting(false)
    }

    private var previewContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Circle()
                    .fill(Color(red: 1.0, green: 0.42, blue: 0.38))
                    .frame(width: 5.5, height: 5.5)
                Text("专注")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.72))
                Spacer()
                Text("第 1/4 轮")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.34))
            }

            Spacer(minLength: 0)

            Text("25:00")
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)

            Text("保持专注 · 结束后提醒")
                .font(.system(size: 9.5))
                .foregroundStyle(Color.white.opacity(0.46))
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
