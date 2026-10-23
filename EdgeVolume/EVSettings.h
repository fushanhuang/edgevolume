#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, EVEdge) {
    EVEdgeLeft = 0,
    EVEdgeRight = 1
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

- (NSString *)volumeCategoryString;

/// 广播设置变更
- (void)postChanged;

extern NSString *const kEVSettingsChangedNotification;

@end
