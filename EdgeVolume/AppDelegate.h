#import <UIKit/UIKit.h>

extern NSString *const kEVOverlayStatusChangedNotification;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

/// 主界面窗口
@property (nonatomic, strong) UIWindow *window;
/// 全局可触摸悬浮窗（音量滑动条）
@property (nonatomic, strong) UIWindow *overlayWindowIsTouch;
/// 全局穿透悬浮窗（HUD 提示）
@property (nonatomic, strong) UIWindow *overlayWindowNoTouch;
/// 两个悬浮窗的根视图控制器
@property (nonatomic, strong) UIViewController *overlayTouchRootVC;
@property (nonatomic, strong) UIViewController *overlayPassRootVC;

/// 悬浮场景标识（对应 UISceneSession.persistentIdentifier）
@property (nonatomic, copy) NSString *touchSceneIdentifier;
@property (nonatomic, copy) NSString *passSceneIdentifier;

/// 运行状态
@property (nonatomic, assign) BOOL shellInitialized;
/// 系统 Shell 是否注册成功（FBSystemShellInitialize 回调后置 YES）
@property (nonatomic, assign, readonly) BOOL shellRegistered;
@property (nonatomic, assign) BOOL touchSceneConnected;
@property (nonatomic, assign) BOOL passSceneConnected;

/// 最近事件日志（设置页诊断用，最新在最后）
@property (nonatomic, strong, readonly) NSArray<NSString *> *eventLog;

/// 必须强引用：场景展示绑定器
@property (nonatomic, strong) id touchBinder;
@property (nonatomic, strong) id passBinder;

/// 启动全局悬浮（FBSystemShellInitialize + 创建两个悬浮场景）
- (void)startFloatingOverlay;
/// 隐藏/显示全部悬浮窗（长按滑条紧急隐藏；打开 App 自动恢复）
- (void)setOverlayHidden:(BOOL)hidden;

- (void)markSceneConnected:(NSString *)identifier;
- (void)markSceneDisconnected:(NSString *)identifier;

@end
