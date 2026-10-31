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

# 把 String Catalog 编译成 en.lproj 里的 .strings / .stringsdict。
# 中文是源语言，文案就是代码里的键，不需要翻译；但 zh-Hans.lproj 里要有文件（空目录不算），系统才认为 App 支持中文
xcrun xcstringstool compile Resources/Localizable.xcstrings --output-directory "$APP/Contents/Resources"
mkdir -p "$APP/Contents/Resources/zh-Hans.lproj"
touch "$APP/Contents/Resources/zh-Hans.lproj/Localizable.strings"

# 本地 ad-hoc 签名；开机自启（SMAppService）要求 app 有签名
codesign --force --sign - "$APP"

echo "Built $APP"
