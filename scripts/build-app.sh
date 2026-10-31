#!/usr/bin/env bash
# 把 SwiftPM 编译出的可执行文件打包成 build/Breather.app
# UNIVERSAL=1 时同时编译 Apple 芯片和 Intel 两种架构，用于分发
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
APP="build/Breather.app"

ARGS=(-c "$CONFIG")
if [[ "${UNIVERSAL:-0}" == 1 ]]; then
    ARGS+=(--arch arm64 --arch x86_64)
fi

swift build "${ARGS[@]}"
BIN_DIR="$(swift build "${ARGS[@]}" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Breather" "$APP/Contents/MacOS/Breather"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# 本地 ad-hoc 签名；开机自启（SMAppService）要求 app 有签名
codesign --force --sign - "$APP"

echo "Built $APP"
