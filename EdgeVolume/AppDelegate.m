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
// 不透明黑底，且层级低于普通窗口——不处理的话，悬浮场景一创建就会
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

    // 1) 占位悬浮窗（FBScene 连接成功后会被 SceneDelegate 替换为绑定全局场景的窗口）
    //    用 EdgeTouchWindow：只有滑条区域接收触摸，其余穿透
    self.overlayTouchRootVC = [[OverlayRootViewController alloc] initWithMode:OverlayModeTouch];
    self.overlayPassRootVC = [[OverlayRootViewController alloc] initWithMode:OverlayModePass];

    self.overlayWindowIsTouch = [[EdgeTouchWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.overlayWindowIsTouch.backgroundColor = [UIColor clearColor];
    self.overlayWindowIsTouch.windowLevel = 10000;
    self.overlayWindowIsTouch.rootViewController = self.overlayTouchRootVC;
    self.overlayWindowIsTouch.hidden = NO;
    [self.overlayWindowIsTouch makeKeyAndVisible];

    self.overlayWindowNoTouch = [[PassThroughWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.overlayWindowNoTouch.backgroundColor = [UIColor clearColor];
    self.overlayWindowNoTouch.windowLevel = 9999;
    self.overlayWindowNoTouch.rootViewController = self.overlayPassRootVC;
    self.overlayWindowNoTouch.hidden = NO;

    // 2) 音量监听（KVO outputVolume）
    [[VolumeController shared] startMonitoring];

    // 3) 全局悬浮（设置里可关；关闭后 App 只作为普通设置页运行）
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
    self.overlayWindowIsTouch.hidden = hidden;
    self.overlayWindowNoTouch.hidden = hidden;
}

- (void)markSceneConnected:(NSString *)identifier {
    if ([identifier isEqualToString:self.touchSceneIdentifier]) self.touchSceneConnected = YES;
    if ([identifier isEqualToString:self.passSceneIdentifier]) self.passSceneConnected = YES;
    [self logEvent:[NSString stringWithFormat:@"场景已连接:%@", identifier]];
    [[NSNotificationCenter defaultCenter] postNotificationName:kEVOverlayStatusChangedNotification object:nil];
}

- (void)markSceneDisconnected:(NSString *)identifier {
    if ([identifier isEqualToString:self.touchSceneIdentifier]) self.touchSceneConnected = NO;
    if ([identifier isEqualToString:self.passSceneIdentifier]) self.passSceneConnected = NO;
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
