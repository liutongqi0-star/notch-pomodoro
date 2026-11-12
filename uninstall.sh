#!/bin/bash
# 卸载应用、登录项，并可选择删除使用记录
set -euo pipefail

LABEL="com.dumaster.usageclock"
APP="$HOME/Applications/UsageClock.app"
AGENT="$HOME/Library/LaunchAgents/${LABEL}.plist"
DATA="$HOME/Library/Application Support/UsageClock"

echo "==> 停止应用"
pkill -x UsageClock >/dev/null 2>&1 || true
launchctl bootout "gui/$(id -u)/${LABEL}" >/dev/null 2>&1 || true
sleep 0.4

echo "==> 移除应用与登录项"
rm -rf "$APP" "$AGENT"

echo "✓ 已移除应用和登录项。"

if [[ "${1:-}" == "--purge" ]]; then
    rm -rf "$DATA"
    echo "✓ 已删除使用记录。"
else
    read -r -p "是否同时删除使用记录？[y/N] " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        rm -rf "$DATA"
        echo "✓ 已删除使用记录。"
    else
        echo "使用记录保留在：$DATA"
    fi
fi
