#import <UIKit/UIKit.h>

extern NSString *const kEVOverlayStatusChangedNotification;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

/// 主界面窗口
@property (nonatomic, strong) UIWindow *window;

/// ===== 第一层：占位悬浮窗（didFinishLaunching 里创建，不依赖场景连接）=====
/// 场景连不上时由它兜底显示音量条（App 前台内可见）
@property (nonatomic, strong) UIWindow *placeholderTouchWindow;
@property (nonatomic, strong) UIWindow *placeholderPassWindow;
@property (nonatomic, strong) UIViewController *placeholderTouchVC;
@property (nonatomic, strong) UIViewController *placeholderPassVC;

/// ===== 第二层：场景悬浮窗（FBScene 连接后由 SceneDelegate 创建）=====
/// 绑定 foreground=YES 的全局场景，App 退到桌面后仍然显示——常驻靠这一层
@property (nonatomic, strong) UIWindow *sceneTouchWindow;
@property (nonatomic, strong) UIWindow *scenePassWindow;
@property (nonatomic, strong) UIViewController *sceneTouchVC;
@property (nonatomic, strong) UIViewController *scenePassVC;

/// 活跃层指针：初始指向占位层；场景层创建后切换过去（HUD 等经此访问）
@property (nonatomic, strong) UIWindow *overlayWindowIsTouch;
@property (nonatomic, strong) UIWindow *overlayWindowNoTouch;
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

/// 场景会话路由状态（SceneDelegate 用）
@property (nonatomic, assign) BOOL mainSceneConnected;
@property (nonatomic, assign) BOOL sceneTouchLayerCreated;
@property (nonatomic, assign) BOOL scenePassLayerCreated;
/// 长按紧急隐藏中（打开 App 自动清除）
@property (nonatomic, assign, readwrite) BOOL overlayHidden;

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
/// 记录一条诊断事件（设置页「运行状态」可见）
- (void)logEvent:(NSString *)event;

@end
