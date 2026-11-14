import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var pomodoro: PomodoroEngine
    @ObservedObject var theme: ThemeModel
    var onClose: () -> Void

    @ObservedObject private var loc = L10n.shared

    private let accent = Color(red: 1.00, green: 0.42, blue: 0.38)

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    timerSection
                    divider
                    themeSection
                    divider
                    generalSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 22)
                .padding(.bottom, 22)
            }

            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1)

            HStack(spacing: 7) {
                Image(systemName: "globe")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)

                Text(loc.t("settings.languageSection"))
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)

                Picker("", selection: languageBinding) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(loc.label(for: language)).tag(language)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                .accessibilityLabel(loc.t("settings.languageSection"))
                .help(loc.t("settings.languageHint"))

                Spacer(minLength: 8)

                Button(loc.t("settings.done")) {
                    onClose()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 470, height: 720)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - 顶部

    private var header: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.00, green: 0.43, blue: 0.36),
                                Color(red: 0.89, green: 0.23, blue: 0.29)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)

                Image(systemName: "timer")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(loc.t("settings.title"))
                    .font(.system(size: 19, weight: .semibold))
                Text(loc.t("settings.subtitle"))
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 计时

    private var timerSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionTitle(loc.t("settings.timerSection"))

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 10
            ) {
                durationField(
                    loc.t("settings.focus"),
                    value: $pomodoro.focusMinutes,
                    range: 1...180,
                    suffix: loc.t("settings.minutesUnit")
                )
                durationField(
                    loc.t("settings.shortBreak"),
                    value: $pomodoro.shortBreakMinutes,
                    range: 1...60,
                    suffix: loc.t("settings.minutesUnit")
                )
                durationField(
                    loc.t("settings.longBreak"),
                    value: $pomodoro.longBreakMinutes,
                    range: 1...120,
                    suffix: loc.t("settings.minutesUnit")
                )
                durationField(
                    loc.t("settings.longBreakInterval"),
                    value: $pomodoro.roundsBeforeLongBreak,
                    range: 2...8,
                    suffix: loc.t("settings.roundsUnit")
                )
            }

            Toggle(isOn: $pomodoro.soundEnabled) {
                HStack(spacing: 8) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(loc.t("settings.sound"))
                        .font(.system(size: 12))
                }
            }
            .toggleStyle(.switch)
            .controlSize(.small)
        }
    }

    private func durationField(
        _ title: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        suffix: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 5) {
                TextField("", value: value, format: .number)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .frame(width: 38)

                Text(suffix)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 2)

                Stepper("", value: value, in: range)
                    .labelsHidden()
                    .controlSize(.mini)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        )
    }

    // MARK: - 主题

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(loc.t("settings.themeSection"))

            ThemePreviewCard(theme: theme)

            HStack(spacing: 12) {
                thumbnail

                VStack(alignment: .leading, spacing: 3) {
                    Text(
                        theme.image == nil
                            ? loc.t("settings.defaultGradient")
                            : loc.t("settings.customImage")
                    )
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)

                    Text(
                        theme.image == nil
                            ? loc.t("settings.chooseImageHint")
                            : loc.t("settings.imageCopiedHint")
                    )
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }

                Spacer(minLength: 4)

                Button(
                    theme.image == nil
                        ? loc.t("settings.chooseImage")
                        : loc.t("settings.changeImage")
                ) {
                    theme.chooseImage()
                }
                .controlSize(.small)

                if theme.image != nil {
                    Button(loc.t("settings.remove")) {
                        theme.removeImage()
                    }
                    .controlSize(.small)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(loc.t("settings.opacity"))
                        .font(.system(size: 11, weight: .medium))
                    Spacer()
                    Text("\(Int((theme.opacity * 100).rounded()))%")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $theme.opacity, in: 0.08...1.0)
                    .tint(accent)
            }

            HStack(spacing: 10) {
                ForEach(GlassStyle.allCases) { style in
                    glassOption(style)
                }
            }

            HStack {
                Text(loc.t("settings.imagePrivacy"))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button(loc.t("settings.resetAppearance")) {
                    theme.resetAppearance()
                }
                .controlSize(.small)
            }
        }
    }

    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.06))

            if let image = theme.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 52, height: 52)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func glassOption(_ style: GlassStyle) -> some View {
        let selected = theme.glass == style
        return Button {
            theme.glass = style
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: style.symbolName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(selected ? accent : Color.secondary)
                    .frame(width: 17)

                VStack(alignment: .leading, spacing: 2) {
                    Text(style.title)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(style.detail)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(selected ? accent.opacity(0.13) : Color.primary.opacity(0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(
                        selected ? accent.opacity(0.65) : Color.primary.opacity(0.07),
                        lineWidth: selected ? 1.3 : 1
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 通用

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(loc.t("settings.general"))

            Toggle(isOn: $model.launchAtLogin) {
                HStack(spacing: 8) {
                    Image(systemName: "power")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(loc.t("settings.launchAtLogin"))
                        .font(.system(size: 12))
                }
            }
            .toggleStyle(.switch)
            .controlSize(.small)

            HStack(spacing: 8) {
                Image(systemName: "folder")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Button(loc.t("settings.openDataFolder")) {
                    model.openDataFolder()
                }
                .buttonStyle(.link)
                Spacer()
            }
            .font(.system(size: 12))
        }
    }


    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { loc.selection },
            set: { loc.set($0) }
        )
    }


    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(.primary)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(height: 1)
    }
}
