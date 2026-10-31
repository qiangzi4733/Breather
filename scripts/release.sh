#!/usr/bin/env bash
# 打包可分发的 dist/Breather-<版本>.zip（Apple 芯片 + Intel 双架构）
#
# 默认是 ad-hoc 签名：别人下载后首次打开会被 Gatekeeper 拦下，需要手动放行。
# 有 Apple 开发者账号后，设置下面两个环境变量即可签名并公证，用户双击就能打开：
#   DEVELOPER_ID   钥匙串里的证书名，如 "Developer ID Application: Your Name (TEAMID)"
#   NOTARY_PROFILE 用 `xcrun notarytool store-credentials <名字>` 保存的凭证名
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/Breather.app"
VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)"
ZIP="dist/Breather-$VERSION.zip"

UNIVERSAL=1 ./scripts/build-app.sh release

if [[ -n "${DEVELOPER_ID:-}" ]]; then
    # 公证要求开启强化运行时并带时间戳
    codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID" "$APP"
    echo "已用 Developer ID 签名"
else
    echo "未设置 DEVELOPER_ID，使用 ad-hoc 签名（未公证）"
fi

mkdir -p dist
rm -f "$ZIP"
# ditto 保留签名和扩展属性，直接用 zip 命令会破坏签名
ditto -c -k --keepParent "$APP" "$ZIP"

if [[ -n "${DEVELOPER_ID:-}" && -n "${NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
    # 把公证结果钉进 app，离线也能通过检查，然后重新打包
    xcrun stapler staple "$APP"
    rm -f "$ZIP"
    ditto -c -k --keepParent "$APP" "$ZIP"
    echo "已公证"
fi

echo
echo "生成 $ZIP"
shasum -a 256 "$ZIP"
