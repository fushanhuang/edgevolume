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

BODY = """## EdgeVolume 1.1.0 — iPad 边缘音量悬浮条 + 键盘快捷键（巨魔专用）

秒空键盘没有音量键？这个 App 在你的 iPad 屏幕边缘放一条几乎透明的音量滑条：**常驻最上层、上下滑动调音量**，看视频、玩游戏时随手一搓就行，不影响屏幕其他区域的操作。**新版还支持硬件键盘组合键调音量**（默认 ⌘++ 增大、⌘+- 减小）。

### 功能
- 屏幕左右边缘常驻半透明音量滑条，**上滑增大、下滑减小**；触控热区默认 44pt（可见轨道仅 10pt），不用精准瞄准
- 只有滑条所在位置可触控，其余区域完全穿透（不挡画面、不挡操作）
- 长按滑条左右拖动可移动位置，松手自动磁吸到左/右边缘；单击显示当前音量
- **键盘快捷键**：⌘++ / ⌘+- 调音量（可自定义修饰键与主键、步进），前台与其他 App 前台均生效
- App 内设置：长度 / 不透明度 / 触控宽度 / 贴边方向 / 锁定位置 / 快捷键 / 保活

### 安装要求
- **iPadOS 16.0 – 17.0**（需可安装巨魔 TrollStore 的版本）
- 已安装 [TrollStore](https://github.com/opa334/TrollStore)

### 安装方法
1. 把 `EdgeVolume.tipa` 传到 iPad（微信文件传输 / AirDrop / iCloud Drive 均可）
2. 选择「用 TrollStore 打开」→ 安装
3. 打开一次「边缘音量」，回桌面即可看到边缘音量条

> 从旧版升级请先在巨魔里卸载旧版再安装。

### 键盘快捷键说明
- 默认 **⌘++ 增大 / ⌘+- 减小**，每次 10%（步进 2%–25% 可调）
- 修饰键可选 ⌘ / ⌥ / ⌃ / ⇧ / 无，主键可选 + / - / ↑ / ↓，增大和减小独立配置
- 实现：前台走 UIKit UIKeyCommand，后台走私有 IOHID 接口监视全系统键盘事件（只观测、不拦截，不影响按键在原 App 的功能）
- 地球键(🌐)是 iPadOS 系统保留键，任何 App 都无法捕获，故提供 ⌘/⌥/⌃/⇧ 替代
- 若同一组合在前台 App 有自带功能（如 Safari ⌘++ 放大页面），两者会同时生效，可改用 ⌥/⌃ 避开
- 后台响应需保持「后台保活」开启；重启 iPad 后需重新打开一次本应用

### 本版更新（相对 v1.0.3）
1. 新增硬件键盘快捷键调音量（上述）
2. 设置页新增「键盘快捷键」分区：组合键配置、步进、诊断日志
3. 修复设置页「当前音量」在快捷键/触摸调节后不刷新的问题

### 自行构建
每次 push 到 main 会自动云构建，产物在 Actions → Artifacts 下载。本地 macOS 构建：
```bash
brew install xcodegen ldid
./build-ipa.sh
```

### 免责声明
基于 FrontBoard / Celestial / IOHID 私有 API 实现，仅供学习交流。使用私有 API 有风险，请自行斟酌。
"""

# 1) 创建 release
payload = {
    "tag_name": TAG,
    "target_commitish": "main",
    "name": "EdgeVolume 1.0.2 — iPad 边缘音量悬浮条",
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
