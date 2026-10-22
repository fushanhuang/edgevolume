#import "AppDelegate.h"
#import "SceneDelegate.h"
#import "UIKitPrivate.h"
#import "OverlayRootViewController.h"
#import "PassThroughWindow.h"
#import "EVSettings.h"
#import "VolumeController.h"

NSString *const kEVOverlayStatusChangedNotification = @"EVOverlayStatusChangedNotification";

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [[EVSettings shared] registerDefaults];

    self.touchSceneIdentifier = @"EVOverlayTouch";
    self.passSceneIdentifier = @"EVOverlayPass";

    // 1) 占位悬浮窗（FBScene 连接成功后会被 SceneDelegate 替换为绑定全局场景的窗口）
    self.overlayTouchRootVC = [[OverlayRootViewController alloc] initWithMode:OverlayModeTouch];
    self.overlayPassRootVC = [[OverlayRootViewController alloc] initWithMode:OverlayModePass];

    self.overlayWindowIsTouch = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.overlayWindowIsTouch.backgroundColor = [UIColor clearColor];
    self.overlayWindowIsTouch.windowLevel = 10000;
    self.overlayWindowIsTouch.rootViewController = self.overlayTouchRootVC;
    self.overlayWindowIsTouch.hidden = NO;

    self.overlayWindowNoTouch = [[PassThroughWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.overlayWindowNoTouch.backgroundColor = [UIColor clearColor];
    self.overlayWindowNoTouch.windowLevel = 9999;
    self.overlayWindowNoTouch.rootViewController = self.overlayPassRootVC;
    self.overlayWindowNoTouch.hidden = NO;

    // 2) 音量监听（KVO outputVolume）
    [[VolumeController shared] startMonitoring];

    // 3) 关键：把本进程注册为系统级 Shell，并向 FrontBoard 注册两个全局悬浮场景
    if (!self.shellInitialized) {
        self.shellInitialized = YES;
        __weak AppDelegate *weakSelf = self;
        FBSystemShellInitialize(^(id arg) {
            __strong AppDelegate *strongSelf = weakSelf;
            if (!strongSelf) return;
            NSLog(@"[EdgeVolume] FBSystemShellInitialize ready, creating floating scenes");
            strongSelf.touchBinder = [strongSelf createFloatingSceneWithIdentifier:strongSelf.touchSceneIdentifier];
            strongSelf.passBinder = [strongSelf createFloatingSceneWithIdentifier:strongSelf.passSceneIdentifier];
        });
    }
    return YES;
}

/// 创建一个全局悬浮 Scene（参照 FrontboardAppLauncher / SysView 的方案）
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

- (void)markSceneConnected:(NSString *)identifier {
    if ([identifier isEqualToString:self.touchSceneIdentifier]) self.touchSceneConnected = YES;
    if ([identifier isEqualToString:self.passSceneIdentifier]) self.passSceneConnected = YES;
    [[NSNotificationCenter defaultCenter] postNotificationName:kEVOverlayStatusChangedNotification object:nil];
}

- (void)markSceneDisconnected:(NSString *)identifier {
    if ([identifier isEqualToString:self.touchSceneIdentifier]) self.touchSceneConnected = NO;
    if ([identifier isEqualToString:self.passSceneIdentifier]) self.passSceneConnected = NO;
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
