#import "AppDelegate.h"
#import "SceneDelegate.h"
#import "UIKitPrivate.h"
#import "OverlayRootViewController.h"
#import "PassThroughWindow.h"
#import "EdgeTouchWindow.h"
#import "EVSettings.h"
#import "VolumeController.h"

NSString *const kEVOverlayStatusChangedNotification = @"EVOverlayStatusChangedNotification";

// ============================================================
// 【黑屏修复 · 关键】
// UIRootWindowScenePresentationBinder 内部会创建私有的 UIRootSceneWindow
// （UIKit 私有 UIWindow 子类）来承载 FBScene 的画面。该窗口默认是
// 不透明黑底，且位于场景内所有窗口之上——不处理的话，悬浮场景一创建就会
// 铺满一整块黑色，盖住 App 自己的界面（用户观感：打开 App 全黑，
// 只有锁屏解锁让系统收回前台场景才能回桌面）。
// 这里用 category 强制它的背景为透明、层级为 10000。
// ============================================================
@interface UIRootSceneWindow : UIWindow
@end

@implementation UIRootSceneWindow (EVHook)

- (void)layoutSubviews {
    [super layoutSubviews];
    self.layer.backgroundColor = UIColor.clearColor.CGColor;
}

- (CGFloat)windowLevel {
    return 10000;
}

@end

@interface AppDelegate ()
@property (nonatomic, assign, readwrite) BOOL shellRegistered;
@property (nonatomic, strong, readwrite) NSArray<NSString *> *eventLog;
@property (nonatomic, strong) NSMutableArray<NSString *> *eventLogStore;

/// 创建一个全局悬浮 Scene，返回其场景展示绑定器（需强引用）
- (id)createFloatingSceneWithIdentifier:(NSString *)sceneIdentifier;
/// 记录一条诊断事件（设置页「运行状态」可见）
- (void)logEvent:(NSString *)event;
@end

@implementation AppDelegate

- (void)logEvent:(NSString *)event {
    if (!self.eventLogStore) self.eventLogStore = [NSMutableArray array];
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = @"HH:mm:ss";
    [self.eventLogStore addObject:[NSString stringWithFormat:@"%@ %@", [fmt stringFromDate:[NSDate date]], event]];
    while (self.eventLogStore.count > 12) {
        [self.eventLogStore removeObjectAtIndex:0];
    }
    self.eventLog = [self.eventLogStore copy];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [[EVSettings shared] registerDefaults];

    self.touchSceneIdentifier = @"EVOverlayTouch";
    self.passSceneIdentifier = @"EVOverlayPass";

    // ===== 第一层：占位悬浮窗 =====
    // 立即创建、立即可见，不依赖 FBScene 连接。
    // 作用：即使悬浮场景没能作为 UIScene 连接进来（或场景层尚未就绪），
    //       App 前台内依然能看到音量条；FBScene 连接成功后由 SceneDelegate
    //       创建第二层（场景窗），两层内容由同一套 EVSettings 驱动、保持同步。
    // EdgeTouchWindow：只有滑条区域接收触摸，其余穿透
    self.placeholderTouchVC = [[OverlayRootViewController alloc] initWithMode:OverlayModeTouch];
    self.placeholderPassVC = [[OverlayRootViewController alloc] initWithMode:OverlayModePass];

    self.placeholderTouchWindow = [[EdgeTouchWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.placeholderTouchWindow.backgroundColor = [UIColor clearColor];
    self.placeholderTouchWindow.windowLevel = 10000;
    self.placeholderTouchWindow.rootViewController = self.placeholderTouchVC;
    self.placeholderTouchWindow.hidden = NO;
    [self.placeholderTouchWindow makeKeyAndVisible];

    self.placeholderPassWindow = [[PassThroughWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.placeholderPassWindow.backgroundColor = [UIColor clearColor];
    self.placeholderPassWindow.windowLevel = 9999;
    self.placeholderPassWindow.rootViewController = self.placeholderPassVC;
    self.placeholderPassWindow.hidden = NO;

    // 活跃层指针：初始指向占位层；场景层就绪后由 SceneDelegate 切换
    self.overlayWindowIsTouch = self.placeholderTouchWindow;
    self.overlayWindowNoTouch = self.placeholderPassWindow;
    self.overlayTouchRootVC = self.placeholderTouchVC;
    self.overlayPassRootVC = self.placeholderPassVC;

    // 音量监听（KVO outputVolume）
    [[VolumeController shared] startMonitoring];

    // 全局悬浮（设置里可关；关闭后 App 只作为普通设置页运行）
    if ([EVSettings shared].overlayEnabled) {
        [self startFloatingOverlay];
    } else {
        [self logEvent:@"全局悬浮已被设置关闭"];
    }
    return YES;
}

- (void)startFloatingOverlay {
    if (self.shellInitialized) return;
    self.shellInitialized = YES;
    __weak AppDelegate *weakSelf = self;
    [self logEvent:@"开始注册系统Shell"];
    // 关键：把本进程注册为系统级 Shell，成功后即可创建压在其他 App 之上的前台场景
    FBSystemShellInitialize(^(id arg) {
        __strong AppDelegate *strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.shellRegistered = YES;
        [strongSelf logEvent:@"Shell注册成功"];
        strongSelf.touchBinder = [strongSelf createFloatingSceneWithIdentifier:strongSelf.touchSceneIdentifier];
        [strongSelf logEvent:@"已创建触摸悬浮场景"];
        strongSelf.passBinder = [strongSelf createFloatingSceneWithIdentifier:strongSelf.passSceneIdentifier];
        [strongSelf logEvent:@"已创建穿透悬浮场景"];
        [[NSNotificationCenter defaultCenter] postNotificationName:kEVOverlayStatusChangedNotification object:nil];
    });
}

/// 创建一个全局悬浮 Scene（参照社区验证过的 SysView 方案）
- (id)createFloatingSceneWithIdentifier:(NSString *)sceneIdentifier {
    FBSceneManager *sharedInstance = [FBSceneManager sharedInstance];

    FBSMutableSceneDefinition *definition = [FBSMutableSceneDefinition definition];
    definition.identity = [FBSSceneIdentity identityForIdentifier:sceneIdentifier];
    definition.clientIdentity = [FBSSceneClientIdentity localIdentity];
    definition.specification = [UIApplicationSceneSpecification specification];

    FBSMutableSceneParameters *parameters = [FBSMutableSceneParameters parametersForSpecification:definition.specification];
    UIMutableApplicationSceneSettings *settings = [UIMutableApplicationSceneSettings new];
    settings.displayConfiguration = [[UIScreen mainScreen] displayConfiguration];
    settings.frame = [[UIScreen mainScreen] _referenceBounds]; // 全屏
    settings.level = 1;
    settings.foreground = YES;                    // 前台场景：不被其他 App 遮挡
    settings.interfaceOrientation = UIInterfaceOrientationPortrait;
    settings.deviceOrientationEventsEnabled = YES;
    settings.interruptionPolicy = 0;              // 参照 FrontBoardAppLauncher：不被打断
    [settings.ignoreOcclusionReasons addObject:@"SystemApp"];
    parameters.settings = settings;

    UIMutableApplicationSceneClientSettings *clientSettings = [UIMutableApplicationSceneClientSettings new];
    clientSettings.interfaceOrientation = UIInterfaceOrientationPortrait;
    clientSettings.statusBarStyle = 0;
    parameters.clientSettings = clientSettings;

    FBScene *scene = [sharedInstance createSceneWithDefinition:definition initialParameters:parameters];

    UIRootWindowScenePresentationBinder *sceneBinder =
        [[UIRootWindowScenePresentationBinder alloc] initWithPriority:0
                                                   displayConfiguration:settings.displayConfiguration];
    [sceneBinder addScene:scene];
    return sceneBinder;
}

- (void)setOverlayHidden:(BOOL)hidden {
    _overlayHidden = hidden;
    // 两层窗口一起动（场景层 + 占位层），确保任何一层可见时都能被紧急隐藏。
    // 注意：不能直接用数组字面量——场景层未创建时对应窗口为 nil，
    // ObjC 集合字面量遇到 nil 会抛异常。
    NSMutableArray *windows = [NSMutableArray array];
    if (self.placeholderTouchWindow) [windows addObject:self.placeholderTouchWindow];
    if (self.placeholderPassWindow)  [windows addObject:self.placeholderPassWindow];
    if (self.sceneTouchWindow)       [windows addObject:self.sceneTouchWindow];
    if (self.scenePassWindow)        [windows addObject:self.scenePassWindow];
    for (UIWindow *w in windows) {
        w.hidden = hidden;
    }
    [self logEvent:hidden ? @"已紧急隐藏全部悬浮窗" : @"已恢复显示悬浮窗"];
}

- (void)markSceneConnected:(NSString *)identifier {
    if ([identifier isEqualToString:self.touchSceneIdentifier]) self.touchSceneConnected = YES;
    if ([identifier isEqualToString:self.passSceneIdentifier]) self.passSceneConnected = YES;
    [self logEvent:[NSString stringWithFormat:@"场景已连接:%@", identifier]];
    [[NSNotificationCenter defaultCenter] postNotificationName:kEVOverlayStatusChangedNotification object:nil];
}

- (void)markSceneDisconnected:(NSString *)identifier {
    if ([identifier isEqualToString:self.touchSceneIdentifier]) {
        self.touchSceneConnected = NO;
        self.sceneTouchLayerCreated = NO;
        self.sceneTouchWindow = nil;
        self.sceneTouchVC = nil;
        // 活跃层回退到占位层，避免悬空指针
        self.overlayWindowIsTouch = self.placeholderTouchWindow;
        self.overlayTouchRootVC = self.placeholderTouchVC;
    }
    if ([identifier isEqualToString:self.passSceneIdentifier]) {
        self.passSceneConnected = NO;
        self.scenePassLayerCreated = NO;
        self.scenePassWindow = nil;
        self.scenePassVC = nil;
        self.overlayWindowNoTouch = self.placeholderPassWindow;
        self.overlayPassRootVC = self.placeholderPassVC;
    }
    [self logEvent:[NSString stringWithFormat:@"场景断开:%@", identifier]];
    [[NSNotificationCenter defaultCenter] postNotificationName:kEVOverlayStatusChangedNotification object:nil];
}

#pragma mark - UISceneSession lifecycle

- (UISceneConfiguration *)application:(UIApplication *)application
            configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession
                                         options:(UISceneConnectionOptions *)options {
    return [[UISceneConfiguration alloc] initWithName:@"Default Configuration"
                                          sessionRole:connectingSceneSession.role];
}

- (void)application:(UIApplication *)application didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions {
}

@end
