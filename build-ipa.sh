#!/bin/bash
# ============================================================
# EdgeVolume 一键构建 + ldid 签名 + 打包 tipa（供巨魔安装）
#
# 依赖：
#   - Xcode（macOS App Store 安装）
#   - ldid（brew install ldid）
#   - xcodegen 仅在使用「无工程源码」时才需要（本仓库已内置
#     EdgeVolume.xcodeproj，正常情况下无需安装）
#
# 用法：./build-ipa.sh
# 产物：EdgeVolume.tipa
# ============================================================
set -euo pipefail
cd "$(dirname "$0")"

ENT_PLIST="$(pwd)/EdgeVolume/entitlements.plist"

echo "==> [1/5] 准备 Xcode 工程"
if [ -d "EdgeVolume.xcodeproj" ]; then
    echo "    使用仓库内置的 EdgeVolume.xcodeproj（无需 xcodegen）"
elif command -v xcodegen >/dev/null 2>&1; then
    echo "    未找到工程文件，使用 xcodegen 生成"
    xcodegen generate
else
    echo "错误：缺少 EdgeVolume.xcodeproj，且未安装 xcodegen" >&2
    echo "请执行：brew install xcodegen && xcodegen generate" >&2
    exit 1
fi

echo "==> [2/5] 编译（不经过 Apple 签名，巨魔会重新签名）"
xcodebuild -project EdgeVolume.xcodeproj \
  -scheme EdgeVolume \
  -configuration Release \
  -sdk iphoneos \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGN_ENTITLEMENTS="" \
  OTHER_CODE_SIGN_FLAGS="" \
  build

APP_PATH="build/Release-iphoneos/EdgeVolume.app"
if [ ! -d "$APP_PATH" ]; then
  echo "错误：未找到 $APP_PATH" >&2
  exit 1
fi

echo "==> [3/5] ldid 签名（写入私有 entitlements）"
if ! command -v ldid >/dev/null 2>&1; then
  echo "错误：未安装 ldid，请执行 brew install ldid" >&2
  exit 1
fi
# 优先对整个 .app 签名；个别 ldid 版本不支持目录时，退回只签主可执行文件
if ! ldid -S"$ENT_PLIST" "$APP_PATH" 2>/dev/null; then
  echo "    ldid 对目录签名失败，改为主可执行文件签名"
  ldid -S"$ENT_PLIST" "$APP_PATH/EdgeVolume"
fi

echo "==> [4/5] 校验签名与 entitlements"
ldid -e "$APP_PATH/EdgeVolume" | head -5

echo "==> [5/5] 打包 tipa"
rm -rf Payload EdgeVolume.tipa
mkdir -p Payload
cp -R "$APP_PATH" Payload/
zip -qr EdgeVolume.tipa Payload
rm -rf Payload

echo ""
echo "============================================================"
echo "构建完成：$(pwd)/EdgeVolume.tipa"
echo ""
echo "安装方法（三选一）："
echo "  1. AirDrop / 微信文件传输 把 EdgeVolume.tipa 发到 iPad，"
echo "     选择「用巨魔(TrollStore)打开」"
echo "  2. 通过 iCloud Drive / 文件 App 分享到巨魔"
echo "  3. 巨魔首页 → 右上角 + → 选择 EdgeVolume.tipa"
echo "============================================================"
