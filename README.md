# 边缘音量 EdgeVolume

一个给 **iPad Pro（M1，iPadOS 17.0）+ 巨魔（TrollStore）** 用的小工具：在屏幕边缘放一条**几乎完全透明**的竖滑条，**常驻在桌面 / 任何 App / 锁屏之上**，随时上下滑动即可调节系统音量——给没有音量键的外接键盘（如秒空键盘）准备的替代方案。

- 上滑 = 音量增大，下滑 = 音量减小
- 左右拖动 = 把滑条挪到别的边缘（松手自动磁吸）
- 单击 = 浮现当前音量提示
- 可设置长度、不透明度、左右边缘、锁定位置

---

## 一、工作原理（为什么普通 App 做不到，巨魔可以）

普通 iOS App 的窗口一旦退到后台就会被系统隐藏，不可能"压"在别的 App 上面。本项目借助巨魔的 **CoreTrust 永久签名 + 任意 entitlements** 能力，复用了社区 2025-2026 年验证过的"全局悬浮窗"方案：

```
┌────────────────────────────────────────────────────────────┐
│  EdgeVolume.app（巨魔安装，platform-application 权限）        │
│                                                            │
│  1. FBSystemShellInitialize()  ← 把自己注册成"系统级 Shell"   │
│  2. FBSceneManager 创建两个 FBScene（foreground=YES，        │
│     ignoreOcclusionReasons=SystemApp，不被任何 App 遮挡）     │
│  3. UIRootWindowScenePresentationBinder 把场景绑到根窗口层    │
│     ├─ 场景 EVOverlayTouch → windowLevel 10000，放音量滑条    │
│     └─ 场景 EVOverlayPass  → _ignoresHitTest 穿透窗，放 HUD  │
│                                                            │
│  4. 调音量：Celestial 私有 API                              │
│     AVSystemController setVolumeTo:forCategory:@"Audio/Video"│
│     （不弹系统音量 HUD；失效时自动回退 MPVolumeView）          │
│  5. 后台保活：静音循环播放（UIBackgroundModes=audio）          │
└────────────────────────────────────────────────────────────┘
```

也就是说：滑条并不是"某个 App 里的控件"，而是**插队到系统桌面前层的独立场景**，因此在你切换到任何 App、回到主屏幕、甚至锁屏时都依然可见可操作。

参考项目（本项目方法与它们同源）：

| 项目 | 说明 |
|---|---|
| [lixuqiang888/IOSFullScreenOverlayWindow-TrollStore](https://github.com/lixuqiang888/IOSFullScreenOverlayWindow-TrollStore) | 巨魔 App 全局悬浮窗完整方案（本项目的场景创建代码来源） |
| [FrontboardAppLauncher](https://github.com/TranKha50277352/FrontboardAppLauncher)（Duy Tran） | 同款 FrontBoard 场景技术，验证支持 iOS 15.0–17.0 |
| [Helium](https://github.com/leminlimez/Helium) | 巨魔全局挂件，iOS 15–17.0 |

> 注：该技术 2026 年初由国内开发者（十三哥）整理开源，iPhone 上已广泛验证；iPad 的 FrontBoard 机制相同，但**你的 M1 iPad + iPadOS 17.0 属于需要实测的环境**，如遇问题请看第八节排错。

---

## 二、环境要求

- iPad Pro M1，**iPadOS 17.0**（17.0.1 起巨魔的 CoreTrust 漏洞已被修复，勿升级）
- 已安装巨魔（TrollStore）
- 构建端二选一：
  - **一台 Mac**（Xcode 15+），或
  - **一个 GitHub 账号**（用 Actions 云构建，无需 Mac）

---

## 三、构建 IPA

> 本仓库**已内置完整的 `EdgeVolume.xcodeproj`**（无需安装 xcodegen，双击即可编译）。
> 工程由 `_tools/gen_xcodeproj.py` 确定性生成，想重新生成或改配置可参考 `project.yml`。

### 方式 A：Mac 本地一键构建（推荐）

```bash
# 安装依赖（一次性，只需要 ldid）
brew install ldid

# 进入项目目录
cd EdgeVolume

# 一键构建 + ldid 签名 + 打包
./build-ipa.sh
```

完成后得到 `EdgeVolume.tipa`（脚本会自动完成：编译 → ldid 写 entitlements → 校验签名 → 打包）。

### 方式 B：Mac 上用 Xcode 手动构建

1. `brew install ldid`
2. `open EdgeVolume.xcodeproj`（无需 xcodegen）
3. 注意：**不要**用 Xcode 的自动签名直接装——私有 entitlements 会被 Apple 签名体系剥掉，悬浮窗会失效。正确做法仍然是跑 `build-ipa.sh`，或：
   - Xcode 里 Product → Build（任意签名/不签名均可）
   - 找到 `build/Release-iphoneos/EdgeVolume.app`
   - `ldid -SEdgeVolume/entitlements.plist build/Release-iphoneos/EdgeVolume.app`
   - 把 `.app` 放进 `Payload` 文件夹压成 `.ipa`/`.tipa`

### 方式 C：没有 Mac，用 GitHub Actions 云构建

1. 把整个 `EdgeVolume` 文件夹（含 `.github` 目录）传为你自己的 GitHub 仓库
2. **推送到 `main`/`master` 分支即自动开始构建**；也可在仓库页面
   **Actions → Build EdgeVolume IPA → Run workflow** 手动触发
3. 约 3–5 分钟后在运行详情里下载构件 `EdgeVolume.tipa`
4. 下载到 iPad（文件 App / AirDrop / 网盘均可）

---

## 四、安装到 iPad

1. 把 `EdgeVolume.tipa` 传到 iPad（微信/QQ 文件传输、AirDrop、iCloud、网盘都行）
2. 点击文件 → **分享 → 巨魔（TrollStore）**
3. 巨弹窗安装时**保留默认的 entitlements 列表**（本项目依赖 `platform-application`、`com.apple.private.security.no-sandbox` 等）
4. 安装完成后，**打开一次「边缘音量」App**（看到设置页即正常），按 Home 键回桌面
5. 屏幕右侧边缘中部会出现一条淡淡的竖滑条——完成

> 若安装后打不开 App：设置 → 隐私与安全性 → 开发者模式，打开并重启一次（仅开发签名测试时需要；巨魔安装一般不需要）。

---

## 五、使用说明

| 操作 | 效果 |
|---|---|
| 在滑条上**上下滑动** | 音量增减（滑条本身长度 = 0%–100%） |
| 在滑条上**左右拖动** | 移动滑条位置，松手磁吸到最近的左/右边缘 |
| **单击**滑条 | 浮现当前音量百分比（1.2 秒后消失） |
| 打开「边缘音量」App | 设置页（长度、透明度、边缘、锁定、保活、测试） |

滑条平时几乎不可见（默认透明度 0.55，视觉元素只有 10pt 宽的细轨 + 中心小圆点），触摸时会稍微变亮作为反馈。

---

## 六、设置项

| 设置 | 说明 |
|---|---|
| 启用悬浮条 | 总开关，关掉后滑条完全消失 |
| 贴边位置 | 左 / 右 |
| 长度 | 滑条轨道长度 80–320pt |
| 不透明度 | 0.05（几乎隐形）– 1.0（清晰可见） |
| 锁定位置 | 禁止拖动，防止误触移动 |
| 触摸模式 | **小窗**（默认，窗口恰好覆盖滑条，窗口外 100% 穿透）/ **全屏**（全屏窗口 + hitTest 穿透） |
| 音量类别 | 媒体音量（默认）/ 铃声音量 |
| 后台保活 | 静音循环播放，保证切 App 后滑条仍可交互；关闭后更省电、不出现在"正在播放" |
| 运行状态 | 显示悬浮场景是否连接、音量 API 用哪条路径 |

---

## 七、已知限制

1. **重启 iPad 后需重新打开一次 App** 滑条才会出现（进程需要被拉起来）。
2. **从后台划掉 App** 后滑条同样消失，重新打开即可。
3. 开启"后台保活"后，控制中心"正在播放"里可能会出现本 App（播放的是静音，可关闭该项）。
4. Stage Manager（多窗口）模式下悬浮窗位置可能异常，建议在 设置 → 主屏与多任务 中关闭 Stage Manager。
5. 极少数情况下系统音量 API 需要切换"音量类别"才生效（设置页有测试按钮）。
6. 该技术较新，若 iPad 上悬浮场景连接失败，请按第八节排查或改用第九节备选方案。

---

## 八、排错

| 现象 | 处理 |
|---|---|
| 设置页显示"悬浮场景:未连接" | 确认 IPA 是用 `ldid -S entitlements.plist` 签名后通过巨魔安装的；确认没有用 Xcode 开发签名直接装；重启 iPad 后重开一次 App |
| 滑条出现了但点不动 / 划不动 | 设置里把"触摸模式"在 小窗/全屏 之间切换一次试试 |
| 滑条出现但整个屏幕点不动 | 说明全屏模式的触摸穿透未生效 → 切换到"小窗"模式（默认即是） |
| 调音量没反应 | 设置页点"测试：把音量设为 50%"；无效则切换"音量类别"（媒体/铃声） |
| 打字时键盘输入异常 | 设置里关闭"后台保活"再试；本应用默认不抢占 Key Window |
| 更新系统后巨魔失效 | iPadOS 17.0.1+ 不再支持巨魔，这是正常现象，与 App 无关 |
| GitHub Actions 构建失败 | 打开失败日志：若卡在 `brew install` 换网络重跑；若报 `scheme not found`，确认上传时没有漏掉 `.github` 目录和 `EdgeVolume.xcodeproj`；若签名步骤失败，确认 `ldid` 已装上（工作流会自动装） |

---

## 九、不装 App 的备选方案（立即可用）

如果暂时不想折腾构建，系统自带能力也能应急：

1. **控制中心**：右上角往下滑 → 音量竖滑条（最快，但需要双手且挡屏幕）。
2. **辅助触控（小白点）**：设置 → 辅助功能 → 触控 → 辅助触控 → 自定顶层菜单加入"设备"，设备菜单里有 **调高音量 / 调低音量**。小球常驻悬浮、全局可用，是系统原生方案。
3. **轻点背面**：设置 → 辅助功能 → 触控 → 轻点背面，可映射"调高音量/调低音量"到双击/三击机身背部。
4. **外接键盘**：部分键盘的 F1/F2 或功能层可发送音量键；或在 设置 → 通用 → 键盘 → 硬件键盘 检查快捷键。

---

## 十、目录结构

```
EdgeVolume/
├── README.md                  ← 本文档
├── EdgeVolume.xcodeproj/      ← 已内置的 Xcode 工程（双击即可编译）
├── project.yml                ← XcodeGen 工程定义（可选，改配置用）
├── build-ipa.sh               ← Mac 一键构建脚本
├── .github/workflows/build.yml← GitHub Actions 云构建
├── _tools/gen_xcodeproj.py    ← 工程生成器（确定性，含结构自检）
└── EdgeVolume/
    ├── AppDelegate.{h,m}      ← 系统级 Shell 注册 + 全局悬浮场景创建
    ├── SceneDelegate.{h,m}    ← 场景连接、旋转跟随
    ├── OverlayRootViewController.{h,m} ← 悬浮窗布局 / 移动 / 磁吸 / HUD
    ├── OverlayContainerView.{h,m}     ← 全屏模式触摸穿透
    ├── EdgeVolumeHandle.{h,m}         ← 音量滑条视图与手势
    ├── VolumeHUDView.{h,m}            ← 音量提示浮层
    ├── PassThroughWindow.{h,m}        ← 穿透窗口（_ignoresHitTest + hitTest 双保险）
    ├── VolumeController.{h,m}         ← 系统音量（私有API+兜底）、保活、KVO
    ├── EVSettings.{h,m}               ← 偏好设置
    ├── SettingsViewController.{h,m}   ← 设置页
    ├── Private/                ← 私有头文件 + FrontBoard 等 .tbd 链接桩
    ├── Info.plist
    ├── entitlements.plist      ← 巨魔签名用权限（关键）
    └── Assets.xcassets/
```

---

## 十一、参考与致谢

- [IOSFullScreenOverlayWindow-TrollStore](https://github.com/lixuqiang888/IOSFullScreenOverlayWindow-TrollStore)（十三哥）——全局悬浮窗方案与私有头文件
- [FrontboardAppLauncher](https://github.com/TranKha50277352/FrontboardAppLauncher)（Duy Tran）——FrontBoard 场景技术
- [Helium](https://github.com/leminlimez/Helium)、[TrollSpeed](https://github.com/Lessica/TrollSpeed)——巨魔全局 HUD 先行者
- [TrollStore](https://github.com/opa334/TrollStore)（opa334）——永久签名与任意 entitlements

## 十二、免责声明

本项目大量使用 iOS 私有 API 与巨魔权限，**仅供个人学习研究使用**，请勿用于任何商业用途或上架。私有 API 可能随系统更新失效，使用本软件产生的一切后果由使用者自行承担。
