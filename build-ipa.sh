#!/bin/bash
# ============================================================
# EdgeVolume 一键构建 + ldid 签名 + 打包 tipa（供巨魔安装）
#
# 依赖：
#   - Xcode（macOS App Store 安装，15.4 及以上均可）
#   - xcodegen（brew install xcodegen）—— 由 project.yml 生成工程
#   - ldid（brew install ldid）—— 把私有 entitlements 写进 Mach-O
#
# 用法：./build-ipa.sh
# 产物：EdgeVolume.tipa
# ============================================================
set -euo pipefail
cd "$(dirname "$0")"

ENT_PLIST="$(pwd)/EdgeVolume/entitlements.plist"
PBXPROJ="EdgeVolume.xcodeproj/project.pbxproj"

# ------------------------------------------------------------
# 兼容垫片：XcodeGen 新版生成的是新版 Xcode 工程格式
# （objectVersion 77 = Xcode 26 / 60 = Xcode 16 / 56 = Xcode 15）。
# 若本机 Xcode 较旧无法解析，自动逐级降级 objectVersion 重试。
# ------------------------------------------------------------
ensure_project_readable() {
  if xcodebuild -project EdgeVolume.xcodeproj -list >/dev/null 2>&1; then
    return 0
  fi
  local msg
  msg="$(xcodebuild -project EdgeVolume.xcodeproj -list 2>&1 || true)"
  if ! printf '%s' "$msg" | grep -q "future Xcode project file format"; then
    echo "错误：Xcode 无法解析工程，且不是版本格式问题：" >&2
    printf '%s\n' "$msg" >&2
    exit 1
  fi
  echo "    当前 Xcode 版本较旧，尝试降级 objectVersion"
  local ver
  for ver in 60 56; do
    sed -i.bak "s/objectVersion = [0-9]*;/objectVersion = $ver;/" "$PBXPROJ"
    rm -f "$PBXPROJ.bak"
    echo "    尝试 objectVersion = $ver"
    if xcodebuild -project EdgeVolume.xcodeproj -list >/dev/null 2>&1; then
      echo "    objectVersion = $ver 可被当前 Xcode 解析"
      return 0
    fi
  done
  echo "错误：降级 objectVersion 后 Xcode 仍无法解析工程" >&2
  exit 1
}

echo "==> [1/5] 用 XcodeGen 生成 Xcode 工程"
if ! command -v xcodegen >/dev/null 2>&1; then
  echo "    未检测到 xcodegen，尝试通过 Homebrew 安装"
  if command -v brew >/dev/null 2>&1; then
    brew install xcodegen
  else
    echo "错误：未安装 xcodegen，且找不到 Homebrew" >&2
    echo "请先安装 Homebrew，然后执行：brew install xcodegen" >&2
    exit 1
  fi
fi
xcodegen --version
xcodegen generate
echo "    已生成 EdgeVolume.xcodeproj（objectVersion: $(grep -o 'objectVersion = [0-9]*' "$PBXPROJ" | head -1 | grep -o '[0-9]*')）"
ensure_project_readable

echo "==> [2/5] 编译（不经过 Apple 签名，巨魔会重新签名）"
# SYMROOT 固定到 ./build，避免产物散落到 DerivedData
xcodebuild -project EdgeVolume.xcodeproj \
  -scheme EdgeVolume \
  -configuration Release \
  -sdk iphoneos \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=NO \
  SYMROOT="$(pwd)/build" \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGN_ENTITLEMENTS="" \
  OTHER_CODE_SIGN_FLAGS="" \
  build

APP_PATH="build/Release-iphoneos/EdgeVolume.app"
# 兜底：若个别 Xcode 版本仍把产物放进 DerivedData，自动定位真实路径
if [ ! -d "$APP_PATH" ]; then
  DD=$(xcodebuild -project EdgeVolume.xcodeproj -scheme EdgeVolume \
        -configuration Release -sdk iphoneos -showBuildSettings 2>/dev/null \
        | awk '/CONFIGURATION_BUILD_DIR =/ {print $3; exit}')
  if [ -n "$DD" ] && [ -d "$DD/EdgeVolume.app" ]; then
    echo "    产物位于 DerivedData：$DD"
    APP_PATH="$DD/EdgeVolume.app"
  fi
fi
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
