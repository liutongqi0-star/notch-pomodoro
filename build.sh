#!/bin/bash
# 构建「番茄钟」macOS 应用（Universal：Apple Silicon + Intel）
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="UsageClock"
APP="${APP_NAME}.app"
BUILD_DIR="build"
SDK="$(xcrun --show-sdk-path)"
MIN_MACOS="14.0"
MODULE_CACHE="$(pwd)/build/ModuleCache"

echo "==> 清理旧构建"
rm -rf "$BUILD_DIR" "$APP"
mkdir -p "$BUILD_DIR" "$APP/Contents/MacOS" "$APP/Contents/Resources" "$MODULE_CACHE"

echo "==> 编译 Swift 源码"
SOURCES=(Sources/*.swift)
for ARCH in arm64 x86_64; do
    echo "    - ${ARCH}"
    xcrun swiftc \
        -O -wmo \
        -sdk "$SDK" \
        -target "${ARCH}-apple-macos${MIN_MACOS}" \
        -module-cache-path "$MODULE_CACHE" \
        -framework AppKit \
        -framework SwiftUI \
        -framework Combine \
        -framework UniformTypeIdentifiers \
        -o "$BUILD_DIR/${APP_NAME}-${ARCH}" \
        "${SOURCES[@]}"
done
lipo -create \
    "$BUILD_DIR/${APP_NAME}-arm64" \
    "$BUILD_DIR/${APP_NAME}-x86_64" \
    -output "$APP/Contents/MacOS/${APP_NAME}"
chmod +x "$APP/Contents/MacOS/${APP_NAME}"

echo "==> 写入 Info.plist"
cp Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "==> 写入本地化资源"
for LANG in en zh-Hans zh-Hant ja ko es fr de; do
    mkdir -p "$APP/Contents/Resources/${LANG}.lproj"
    cp "Resources/${LANG}.lproj/InfoPlist.strings" \
        "$APP/Contents/Resources/${LANG}.lproj/InfoPlist.strings"
done

echo "==> 生成 App 图标"
xcrun swiftc \
    -O \
    -sdk "$SDK" \
    -target "arm64-apple-macos${MIN_MACOS}" \
    -module-cache-path "$MODULE_CACHE" \
    -framework AppKit \
    -o "$BUILD_DIR/makeicon" \
    Tools/MakeIcon.swift
"$BUILD_DIR/makeicon" "$BUILD_DIR/icon-1024.png"

ICONSET="$BUILD_DIR/AppIcon.iconset"
mkdir -p "$ICONSET"
for SIZE in 16 32 128 256 512; do
    sips -z "$SIZE" "$SIZE" "$BUILD_DIR/icon-1024.png" \
        --out "$ICONSET/icon_${SIZE}x${SIZE}.png" >/dev/null
    DOUBLE=$((SIZE * 2))
    sips -z "$DOUBLE" "$DOUBLE" "$BUILD_DIR/icon-1024.png" \
        --out "$ICONSET/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

echo "==> 校验与签名"
plutil -lint "$APP/Contents/Info.plist" >/dev/null
codesign --force --deep --sign - "$APP"
codesign --verify --strict "$APP"

echo "==> 打包 zip"
ditto -c -k --keepParent "$APP" "$BUILD_DIR/${APP_NAME}.zip"

echo
echo "✓ 构建完成"
echo "  应用：$(pwd)/$APP"
echo "  压缩包：$(pwd)/$BUILD_DIR/${APP_NAME}.zip"
lipo -info "$APP/Contents/MacOS/${APP_NAME}"
