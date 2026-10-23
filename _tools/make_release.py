#!/usr/bin/env python3
"""创建 GitHub Release 并上传 EdgeVolume.tipa
用法: python make_release.py [版本号，默认 v1.0.3]
"""
import json
import subprocess
import sys
import os

REPO = "fushanhuang/edgevolume"
TAG = sys.argv[1] if len(sys.argv) > 1 else "v1.0.3"
TIPA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "EdgeVolume.tipa")

def get_token():
    out = subprocess.run(
        ["git", "credential", "fill"],
        input="url=https://github.com\n\n",
        capture_output=True, text=True,
    ).stdout
    for line in out.splitlines():
        if line.startswith("password="):
            return line.split("=", 1)[1]
    raise RuntimeError("无法从 git credential 获取 token")

TOKEN = get_token()
print("token 获取成功")

BODY = """## EdgeVolume 1.2.0 — iPad 边缘音量悬浮条（巨魔专用）

妙控键盘没有音量键？这个 App 在你的 iPad 屏幕边缘放一条几乎透明的音量滑条：**常驻最上层、上下滑动调音量**，看视频、玩游戏时随手一搓就行，不影响屏幕其他区域的操作。

### 功能
- 屏幕左右边缘常驻半透明音量滑条，**上滑增大、下滑减小**
- **轨道粗细可调**（默认 20pt，10–44pt）——加粗后手指更容易点中，圆角和中心圆点自动适配
- 触控热区默认 44pt，比可见滑条宽，不用精准瞄准；除热区外的触摸全部穿透到下层 App
- 长按滑条左右拖动可移动位置，松手自动磁吸到左/右边缘；单击显示当前音量
- App 内设置：长度 / 不透明度 / 轨道粗细 / 触控宽度 / 贴边方向 / 锁定位置 / 音量类别 / 后台保活

### 安装要求
- **iPadOS 16.0 – 17.0**（需可安装巨魔 TrollStore 的版本）
- 已安装 [TrollStore](https://github.com/opa334/TrollStore)

### 安装方法
1. 把 `EdgeVolume.tipa` 传到 iPad（微信文件传输 / AirDrop / iCloud Drive 均可）
2. 选择「用 TrollStore 打开」→ 安装
3. 打开一次「边缘音量」，回桌面即可看到边缘音量条

> 从旧版升级请先在巨魔里卸载旧版再安装。

### 本版更新（相对 v1.1.2）
1. **移除硬件键盘快捷键功能**：经真机验证，iPadOS 只把键盘事件分发给当前前台 App（iOS 安全模型，后台进程无法旁观其他 App 的键盘输入），巨魔又不能注入系统进程，跨 App 组合键调音量在技术上无法实现。相关设置项已全部移除，避免误以为可用
2. 「运行状态」一栏新增**后台保活健康度**实时显示：滑条常驻依赖它——被抖音等视频 App 抢占音频会话后进程可能被挂起、滑条冻住，新版会自动恢复（中断结束/切回本 App 时重建会话 + 20 秒看门狗），异常时这一栏会明示
3. 键盘替代方案（README 第五节有详细说明）：**带音量键/旋钮的蓝牙键盘**（iPadOS 原生支持 HID 音量键，任何 App 里按一下即调）、嘿 Siri、或本 App 的边缘滑条

### 自行构建
每次 push 到 main 会自动云构建，产物在 Actions → Artifacts 下载。本地 macOS 构建：
```bash
brew install xcodegen ldid
./build-ipa.sh
```

### 免责声明
基于 FrontBoard / Celestial 私有 API 实现，仅供学习交流。使用私有 API 有风险，请自行斟酌。
"""

# 1) 创建 release
payload = {
    "tag_name": TAG,
    "target_commitish": "main",
    "name": "EdgeVolume 1.2.0 — iPad 边缘音量悬浮条",
    "body": BODY,
    "draft": False,
    "prerelease": False,
}
r = subprocess.run(
    ["curl", "-s", "-X", "POST",
     "-H", f"Authorization: token {TOKEN}",
     "-H", "Accept: application/vnd.github+json",
     "https://api.github.com/repos/" + REPO + "/releases",
     "-d", json.dumps(payload)],
    capture_output=True, text=True,
)
data = json.loads(r.stdout)
if "id" not in data:
    print("创建 release 失败:", json.dumps(data, ensure_ascii=False)[:500])
    sys.exit(1)
print("release 创建成功: id =", data["id"], "| tag =", data["tag_name"])
upload_base = data["upload_url"].split("{")[0]
print("upload url:", upload_base)

# 2) 上传 tipa
size = os.path.getsize(TIPA)
print(f"上传 {TIPA} ({size} bytes) ...")
r2 = subprocess.run(
    ["curl", "-s", "-X", "POST",
     "-H", f"Authorization: token {TOKEN}",
     "-H", "Accept: application/vnd.github+json",
     "-H", "Content-Type: application/octet-stream",
     "--data-binary", "@" + TIPA,
     f"{upload_base}?name=EdgeVolume.tipa"],
    capture_output=True, text=True,
)
d2 = json.loads(r2.stdout)
if "id" not in d2:
    print("上传失败:", json.dumps(d2, ensure_ascii=False)[:500])
    sys.exit(1)
print("上传成功: asset id =", d2["id"], "| download_count =", d2["download_count"])
print("下载地址:", d2["browser_download_url"])
print()
print("Release 页面: https://github.com/" + REPO + "/releases/tag/" + TAG)
