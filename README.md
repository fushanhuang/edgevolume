# 边缘音量 EdgeVolume

一个给 **iPad Pro（M1，iPadOS 17.0）+ 巨魔（TrollStore）** 用的小工具：在屏幕边缘放一条**几乎完全透明**的竖滑条，**常驻在桌面 / 任何 App / 锁屏之上**，随时上下滑动即可调节系统音量——给没有音量键的外接键盘（如秒空键盘）准备的替代方案。

- 上滑 = 音量增大，下滑 = 音量减小
- 左右拖动 = 把滑条挪到别的边缘（松手自动磁吸）
- 单击 = 浮现当前音量提示
- 可设置长度、不透明度、触控宽度、左右边缘、锁定位置

## 直接下载安装（无需构建）

**[>>> 前往 Releases 下载 EdgeVolume.tipa <<<](https://github.com/fushanhuang/edgevolume/releases/latest)**

安装方法：把 `EdgeVolume.tipa` 传到 iPad（微信文件传输 / AirDrop / iCloud Drive 均可）→ 选择「用 TrollStore 打开」→ 安装 → 打开一次「边缘音量」，回桌面即可看到边缘音量条。要求 **iPadOS 16.0–17.0 + TrollStore**，升级前请先在巨魔里卸载旧版。

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

> 工程文件由 **XcodeGen** 从 `project.yml` 生成（`EdgeVolume.xcodeproj` 不纳入版本管理）。
> 需要安装两个命令行工具：`xcodegen`（生成工程）和 `ldid`（写私有 entitlements）。
> Xcode 版本要求 **15.4 及以上**；若本机 Xcode 较旧，`build-ipa.sh` 会自动把工程
> 的 `objectVersion` 逐级降级（77→60→56）后重试，无需手动干预。

### 方式 A：Mac 本地一键构建（推荐）

```bash
# 安装依赖（一次性）
brew install xcodegen ldid

# 进入项目目录
cd EdgeVolume

# 一键构建 + ldid 签名 + 打包
./build-ipa.sh
```

脚本会自动完成：`xcodegen generate` → 编译 → ldid 写 entitlements → 校验签名 → 打包。
完成后得到 `EdgeVolume.tipa`。

### 方式 B：Mac 上用 Xcode 手动构建

1. `brew install xcodegen ldid`
2. `xcodegen generate && open EdgeVolume.xcodeproj`
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

> 本仓库的成品包直接发布在 **[Releases](https://github.com/fushanhuang/edgevolume/releases/latest)**，不想自己构建的话下载即用。

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
| **长按**滑条 0.7 秒 | 紧急隐藏全部悬浮窗（打开 App 自动恢复） |
| **键盘快捷键**（默认 ⌘++ 增大 / ⌘+- 减小） | 随时调音量，不用碰屏幕；组合键可在设置里自定义 |
| 打开「边缘音量」App | 设置页（长度、透明度、边缘、锁定、保活、快捷键、测试） |

滑条平时几乎不可见（默认透明度 0.55，视觉元素只有 10pt 宽的细轨 + 中心小圆点），触摸时会稍微变亮作为反馈。**触控热区默认 44pt**，比可见滑条宽得多，不用精准瞄准；热区宽度可在设置里调整（26–120pt），除热区外的所有触摸全部穿透到下层 App。

**关于「只占滑条那一块」**：悬浮窗不会覆盖整个屏幕——除滑条本身（含约 14pt 抓取边距）外，所有触摸都会穿透到下层的 App / 桌面，视频、游戏、网页操作均不受影响。实现上做了两层穿透：①触摸窗口（EdgeTouchWindow）在非滑条区域 hitTest 返回 nil；②HUD 提示窗（PassThroughWindow）整窗 `_ignoresHitTest` + hitTest 返回 nil，永远不拦截触摸。

### 键盘快捷键（给没有音量键的键盘）

秒空键盘这类没有音量键的外接键盘，可以用组合键调音量：

- **默认组合**：⌘++ 增大、⌘+- 减小（每次 10%，步进可调 2%–25%）
- **可自定义**：修饰键支持 ⌘ / ⌥ / ⌃ / ⇧ / 无，主键支持 + / - / ↑ / ↓，增大和减小可分别配置
- **生效范围**：App 在前台和其他 App 前台时都能用——前台走 UIKit 的 UIKeyCommand，后台走私有 IOHID 接口监视全系统键盘事件（只观测、不拦截，不影响按键在原 App 里的功能）
- **注意事项**：
  - 地球键(🌐)是 iPadOS 系统保留键（⌘+类组合由系统直接处理），**无法被 App 捕获**，所以提供 ⌘/⌥/⌃/⇧ 替代；如确实需要地球键，可在 设置 → 通用 → 键盘 → 实体键盘 → 修饰键 里把某个修饰键重映射为地球键再配合使用
  - 同一组合键在前台 App 里可能有自带功能（如 Safari 的 ⌘++ 是放大页面），两者会同时生效——介意的话改用 ⌥ 或 ⌃
  - 退到后台后快捷键要继续响应，需保持「后台保活」开启（默认开）
  - 重启 iPad 后需重新打开一次本应用，快捷键恢复响应
- **诊断**：设置页「捕获状态」一栏会显示私有接口是否可用、当前组合和最近捕获的按键；打开「诊断：记录所有按键」后，所有按键事件（含厂商页特殊键）都会记录，便于反馈问题

---

## 六、设置项

| 设置 | 说明 |
|---|---|
| 全局悬浮窗 | 总闸：关闭后 App 只作为普通设置页运行，不创建任何悬浮场景 |
| 启用悬浮条 | 总开关，关掉后滑条完全消失 |
| 贴边位置 | 左 / 右 |
| 长度 | 滑条轨道长度 80–320pt |
| 不透明度 | 0.05（几乎隐形）– 1.0（清晰可见） |
| 触控宽度 | 触摸热区宽度 26–120pt（默认 44pt）。**只加宽触控、不改外观**——可见轨道始终是 10pt 细轨，热区加宽后手指不用瞄得很准 |
| 锁定位置 | 禁止拖动，防止误触移动 |
| 触摸模式 | **小窗**（默认，悬浮窗口恰好覆盖滑条热区，窗口外 100% 穿透）/ **全屏**（窗口全屏，但命中测试严格限定在滑条热区内，热区外一律穿透） |
| 音量类别 | 媒体音量（默认）/ 铃声音量 |
| 启用键盘快捷键 | 总开关（默认开）。开启后可用组合键调音量 |
| 增大/减小－修饰键、主键 | 分别配置两组组合键，修饰键支持 ⌘/⌥/⌃/⇧/无，主键支持 +/-/↑/↓ |
| 每次步进 | 每按一次快捷键的音量变化量 2%–25%（默认 10%） |
| 诊断：记录所有按键 | 记录所有捕获到的按键事件（含厂商页特殊键），显示在「捕获状态」一栏 |
| 后台保活 | 静音循环播放，保证切 App 后滑条仍可交互、快捷键仍响应；关闭后更省电、不出现在"正在播放" |
| 运行状态 | 显示系统Shell/悬浮场景/音量API 状态 + 最近事件日志 |

---

## 七、已知限制

1. **重启 iPad 后需重新打开一次 App** 滑条才会出现（进程需要被拉起来）。
2. **从后台划掉 App** 后滑条同样消失，重新打开即可。
3. 开启"后台保活"后，控制中心"正在播放"里可能会出现本 App（播放的是静音，可关闭该项）。
4. Stage Manager（多窗口）模式下悬浮窗位置可能异常，建议在 设置 → 主屏与多任务 中关闭 Stage Manager。
5. 极少数情况下系统音量 API 需要切换"音量类别"才生效（设置页有测试按钮）。
6. 该技术较新，若 iPad 上悬浮场景连接失败，请按第八节排查或改用第九节备选方案。
7. **键盘快捷键依赖私有 IOHID 接口**：若个别系统版本/权限组合下后台监听不可用（设置页「捕获状态」会显示），前台快捷键仍可用；地球键为系统保留键，任何方案都无法捕获。

---

## 八、排错

| 现象 | 处理 |
|---|---|
| 打开 App 全黑、只有锁屏解锁才能回桌面 | v1.0.1 已修复（binder 场景窗口黑底问题，见 AppDelegate.m 中 `UIRootSceneWindow` hook）。若仍遇到：长按滑条 0.7 秒可紧急隐藏悬浮窗，或设置里关掉"全局悬浮窗" |
| 桌面上没有音量条 | 看设置页"运行状态"：① 显示"场景层:已创建"仍没有 → 重启 iPad 后重开 App；② 显示"场景层:未创建" → 把事件日志截图反馈（日志里有每个场景会话的连接情况）；③ 显示"占位层:显示中"说明 App 前台内能看到滑条，问题只在后台常驻 |
| 设置页显示"系统Shell:未注册" | 确认 entitlements 完整签名（`ldid -S`）；确认通过巨魔安装而非 Xcode 直装 |
| 滑条出现了但点不动 / 划不动 | 设置里把"触摸模式"在 小窗/全屏 之间切换一次试试 |
| 滑条出现但整个屏幕点不动 | 说明全屏模式的触摸穿透未生效 → 切换到"小窗"模式（默认即是） |
| 调音量没反应 | 设置页点"测试：把音量设为 50%"；无效则切换"音量类别"（媒体/铃声） |
| 快捷键没反应（任何 App 里按都没用） | 看「捕获状态」一栏：① 显示"后台监听不可用"→ 私有接口在本机受限，前台快捷键仍可用；② 显示"后台监听中"但按了没反应 → 打开"诊断：记录所有按键"再按几下，看"最近捕获"里有没有出现按键记录，把截图反馈；③ 确认「后台保活」开着（后台响应依赖它） |
| 快捷键在前台 App 里触发了别的功能（如 Safari 放大） | 本方案只观测不拦截，原 App 的自带功能会同时生效；把修饰键改成 ⌥ 或 ⌃ 避开 |
| 想用地球键(🌐)组合但没反应 | 地球键是系统保留键，无法被 App 捕获（iPadOS 限制），请改用 ⌘/⌥/⌃/⇧ |
| 打字时键盘输入异常 | 设置里关闭"后台保活"再试；本应用默认不抢占 Key Window |
| 更新系统后巨魔失效 | iPadOS 17.0.1+ 不再支持巨魔，这是正常现象，与 App 无关 |
| GitHub Actions 构建失败 | 打开失败日志：若卡在 `brew install` 换网络重跑；若报 `scheme not found`，确认上传时没有漏掉 `.github` 目录和 `EdgeVolume.xcodeproj`；若签名步骤失败，确认 `ldid` 已装上（工作流会自动装） |

> 设置页「运行状态」一栏会显示 系统Shell / 悬浮场景 / 音量API 状态和最近 6 条事件日志，排查问题时先看这里，把截图发给开发者即可快速定位。

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
├── project.yml                ← XcodeGen 工程定义（唯一工程配置来源）
├── build-ipa.sh               ← Mac 一键构建脚本
├── .github/workflows/build.yml← GitHub Actions 云构建
└── EdgeVolume/
    ├── AppDelegate.{h,m}      ← 系统级 Shell 注册 + 全局悬浮场景创建
    ├── SceneDelegate.{h,m}    ← 场景连接、旋转跟随
    ├── OverlayRootViewController.{h,m} ← 悬浮窗布局 / 移动 / 磁吸 / HUD
    ├── OverlayContainerView.{h,m}     ← 全屏模式触摸穿透
    ├── EdgeVolumeHandle.{h,m}         ← 音量滑条视图与手势
    ├── VolumeHUDView.{h,m}            ← 音量提示浮层
    ├── PassThroughWindow.{h,m}        ← 穿透窗口（_ignoresHitTest + hitTest 双保险）
    ├── VolumeController.{h,m}         ← 系统音量（私有API+兜底）、保活、KVO
    ├── KeyboardShortcutController.{h,m} ← 硬件键盘快捷键：IOHID 后台监听 + 前台 UIKeyCommand
    ├── EVSettings.{h,m}               ← 偏好设置
    ├── SettingsViewController.{h,m}   ← 设置页
    ├── Private/                ← 私有头文件（UIKit/AVSystemController/FrontBoard/IOHID）+ .tbd 链接桩
    ├── Info.plist
    ├── entitlements.plist      ← 巨魔签名用权限（关键）
    └── Assets.xcassets/
```

> `EdgeVolume.xcodeproj/` 由 `xcodegen generate` 生成，不纳入版本管理（见 `.gitignore`）。

---

## 十一、参考与致谢

- [IOSFullScreenOverlayWindow-TrollStore](https://github.com/lixuqiang888/IOSFullScreenOverlayWindow-TrollStore)（十三哥）——全局悬浮窗方案与私有头文件
- [FrontboardAppLauncher](https://github.com/TranKha50277352/FrontboardAppLauncher)（Duy Tran）——FrontBoard 场景技术
- [Helium](https://github.com/leminlimez/Helium)、[TrollSpeed](https://github.com/Lessica/TrollSpeed)——巨魔全局 HUD 先行者
- [TrollStore](https://github.com/opa334/TrollStore)（opa334）——永久签名与任意 entitlements

## 十二、免责声明

本项目大量使用 iOS 私有 API 与巨魔权限，**仅供个人学习研究使用**，请勿用于任何商业用途或上架。私有 API 可能随系统更新失效，使用本软件产生的一切后果由使用者自行承担。
