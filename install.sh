#!/bin/bash
# 安装到 ~/Applications，并设置登录时自动启动
set -euo pipefail
cd "$(dirname "$0")"

SRC="$(pwd)/UsageClock.app"
DEST="$HOME/Applications/UsageClock.app"
AGENT_DIR="$HOME/Library/LaunchAgents"
AGENT="$AGENT_DIR/com.dumaster.usageclock.plist"
LABEL="com.dumaster.usageclock"

if [[ ! -d "$SRC" ]]; then
    echo "未找到 UsageClock.app，请先运行 ./build.sh"
    exit 1
fi

mkdir -p "$HOME/Applications" "$AGENT_DIR"

if pgrep -x UsageClock >/dev/null 2>&1; then
    echo "==> 退出正在运行的旧版本"
    pkill -x UsageClock >/dev/null 2>&1 || true
    sleep 0.6
fi

echo "==> 安装应用"
rm -rf "$DEST"
ditto "$SRC" "$DEST"
codesign --force --sign - "$DEST" >/dev/null 2>&1 || true

echo "==> 配置登录时自动启动"
cat > "$AGENT" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${DEST}/Contents/MacOS/UsageClock</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>ProcessType</key>
    <string>Interactive</string>
</dict>
</plist>
PLIST

launchctl bootout "gui/$(id -u)/${LABEL}" >/dev/null 2>&1 || true
open "$DEST"

echo
echo "✓ 安装完成：$DEST"
echo "  平时彩虹会环绕刘海流动；把鼠标移到刘海处展开番茄钟和备忘录。"
echo "  专注/休息结束时会只弹出计时卡片提醒。"
echo "  点计时卡片右上角的齿轮，或 ⋯ 菜单，可以改主题和时长。"
echo "  登录时自动启动已开启，可在菜单栏里随时关闭。"
