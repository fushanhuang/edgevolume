#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, EVEdge) {
    EVEdgeLeft = 0,
    EVEdgeRight = 1
};

/// 快捷键修饰键
typedef NS_ENUM(NSInteger, EVKBModifier) {
    EVKBModifierNone = 0,    // 无修饰键
    EVKBModifierCommand,     // ⌘
    EVKBModifierOption,      // ⌥
    EVKBModifierControl,     // ⌃
    EVKBModifierShift        // ⇧
};

/// 快捷键主键
typedef NS_ENUM(NSInteger, EVKBKey) {
    EVKBKeyPlus = 0,         // +（即 = 键，HID usage 0x2E）
    EVKBKeyMinus,            // -（HID usage 0x2D）
    EVKBKeyUpArrow,          // ↑（HID usage 0x52）
    EVKBKeyDownArrow         // ↓（HID usage 0x51）
};

/// 全局偏好设置（NSUserDefaults 封装）
@interface EVSettings : NSObject

+ (instancetype)shared;

/// 注册默认值，请在 AppDelegate 启动时调用
- (void)registerDefaults;

/// 悬浮条总开关
@property (nonatomic, assign) BOOL enabled;
/// 全局悬浮窗总开关（关闭后 App 仅作为普通设置页运行，不创建悬浮场景）
@property (nonatomic, assign) BOOL overlayEnabled;
/// 贴靠边缘（左/右）
@property (nonatomic, assign) EVEdge edge;
/// 垂直位置（0=顶部 1=底部，相对可用区域）
@property (nonatomic, assign) CGFloat centerYFraction;
/// 轨道长度（pt）
@property (nonatomic, assign) CGFloat trackLength;
/// 轨道粗细（pt）：可见滑条的视觉宽度，加粗后手指更容易点中（默认 20pt，10–44 可调）
@property (nonatomic, assign) CGFloat trackThickness;
/// 触控宽度（pt）：把手的触摸热区宽度。热区比可见轨道宽，手指更好命中、
/// 不影响外观（默认 44pt，26–120 可调）
@property (nonatomic, assign) CGFloat touchWidth;
/// 整体不透明度 0.05 ~ 1.0
@property (nonatomic, assign) CGFloat trackAlpha;
/// 锁定位置（禁止拖动移动）
@property (nonatomic, assign) BOOL lockPosition;
/// 触摸窗口模式：YES=小窗模式（窗口即悬浮条，默认，绝对穿透）；NO=全屏窗口+hitTest 穿透
@property (nonatomic, assign) BOOL smallWindowMode;
/// 后台静音播放保活
@property (nonatomic, assign) BOOL keepAlive;
/// 音量类别：0=媒体音量(Audio/Video) 1=铃声音量(Ringtone)
@property (nonatomic, assign) NSInteger volumeCategory;

#pragma mark - 键盘快捷键

/// 键盘快捷键总开关
@property (nonatomic, assign) BOOL kbEnabled;
/// 增大音量组合：修饰键 / 主键
@property (nonatomic, assign) EVKBModifier kbUpModifier;
@property (nonatomic, assign) EVKBKey kbUpKey;
/// 减小音量组合：修饰键 / 主键
@property (nonatomic, assign) EVKBModifier kbDownModifier;
@property (nonatomic, assign) EVKBKey kbDownKey;
/// 每次按键的音量步进 0.02 ~ 0.25
@property (nonatomic, assign) CGFloat kbStep;
/// 诊断模式：记录所有捕获到的按键事件（设置页可见）
@property (nonatomic, assign) BOOL kbDiagnostic;

- (NSString *)volumeCategoryString;

/// 广播设置变更
- (void)postChanged;

extern NSString *const kEVSettingsChangedNotification;

@end
