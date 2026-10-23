#import "SceneDelegate.h"
#import "AppDelegate.h"
#import "OverlayRootViewController.h"
#import "OverlayContainerView.h"
#import "PassThroughWindow.h"
#import "EdgeTouchWindow.h"
#import "SettingsViewController.h"
#import "UIKitPrivate.h"
#import "EVSettings.h"
#import "VolumeController.h"

NSString *const kEVFloatingWindowDidRotateNotification = @"EVFloatingWindowDidRotateNotification";

@interface SceneDelegate ()
@property (nonatomic, strong) FBSOrientationObserver *orientationObserver;
/// 本实例是否负责主界面场景（每个 UIScene 会话有独立的 SceneDelegate 实例，
/// 用实例标志判断比标识符匹配更可靠——系统可能下发生成 ID 而非 FBScene 标识）
@property (nonatomic, assign) BOOL isMainScene;
@end

@implementation SceneDelegate

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    if (![scene isKindOfClass:[UIWindowScene class]]) return;
    UIWindowScene *windowScene = (UIWindowScene *)scene;
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    NSString *ident = session.persistentIdentifier ?: @"";
    NSString *bundleID = NSBundle.mainBundle.bundleIdentifier ?: @"";

    // ===== 会话路由 =====
    // 1) 主界面：persistentIdentifier 为包名，或为系统生成的 ID
    //    （SupportsMultipleScenes=true 时主会话 ID 由系统生成）——
    //    用「首个连接的非悬浮会话」兜底识别。
    // 2) 悬浮场景：标识为 EVOverlayTouch / EVOverlayPass（FBScene 标识，
    //    与参照实现一致）；若系统下发的是生成 ID，按创建顺序兜底
    //    （先触摸层、后穿透层）。
    BOOL isMain = [ident isEqualToString:bundleID];
    if (!isMain
        && ![ident isEqualToString:ad.touchSceneIdentifier]
        && ![ident isEqualToString:ad.passSceneIdentifier]
        && !ad.mainSceneConnected) {
        isMain = YES;
    }

    if (isMain) {
        // ===== 应用主界面（设置页）=====
        ad.mainSceneConnected = YES;
        self.isMainScene = YES;
        self.window = [[UIWindow alloc] initWithWindowScene:windowScene];
        SettingsViewController *settings = [[SettingsViewController alloc] initWithStyle:UITableViewStyleGrouped];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:settings];
        self.window.rootViewController = nav;
        [self.window makeKeyAndVisible];
        ad.window = self.window;
        [[VolumeController shared] ensureVolumeView];
        [ad logEvent:[NSString stringWithFormat:@"主界面场景已连接:%@", ident]];
    } else {
        BOOL wantTouch = [ident isEqualToString:ad.touchSceneIdentifier];
        BOOL wantPass  = [ident isEqualToString:ad.passSceneIdentifier];
        if (!wantTouch && !wantPass) {
            // 系统下发了生成 ID：按创建顺序兜底分派
            if (!ad.sceneTouchLayerCreated)      wantTouch = YES;
            else if (!ad.scenePassLayerCreated)  wantPass  = YES;
        }

        if (wantTouch && !ad.sceneTouchLayerCreated) {
            [self createSceneTouchLayerWithWindowScene:windowScene appDelegate:ad];
        } else if (wantPass && !ad.scenePassLayerCreated) {
            [self createScenePassLayerWithWindowScene:windowScene appDelegate:ad];
        } else {
            [ad logEvent:[NSString stringWithFormat:@"忽略额外场景会话:%@", ident]];
            return;
        }
    }

    // 除触摸层外，窗口统一铺满场景（触摸层由 OverlayRootViewController
    // 按「小窗模式」收缩到恰好覆盖滑条）
    if (!(self.window == ad.sceneTouchWindow)) {
        self.window.frame = windowScene.coordinateSpace.bounds;
    }

    // 悬浮层跟随设备旋转（主界面由系统自动处理）
    if (!isMain) {
        [self setupOrientationObserver];
    }
}

#pragma mark - 第二层：场景悬浮窗

/// 创建绑定全局前台场景的可触摸层（音量滑动条）。
/// FBScene 标记了 foreground=YES 且 ignoreOcclusionReasons=SystemApp，
/// 因此这一层在 App 退到桌面/其他 App 之后依然显示——常驻音量条靠它。
- (void)createSceneTouchLayerWithWindowScene:(UIWindowScene *)windowScene appDelegate:(AppDelegate *)ad {
    OverlayRootViewController *vc = [[OverlayRootViewController alloc] initWithMode:OverlayModeTouch];
    // EdgeTouchWindow：窗口内非滑条区域 hitTest 返回 nil，触摸穿透到下层
    EdgeTouchWindow *w = [[EdgeTouchWindow alloc] initWithWindowScene:windowScene];
    w.backgroundColor = [UIColor clearColor];
    w.windowLevel = 10000;
    w.rootViewController = vc;
    self.window = w;

    ad.sceneTouchWindow = w;
    ad.sceneTouchVC = vc;
    ad.sceneTouchLayerCreated = YES;
    // 活跃层切换到场景层
    ad.overlayWindowIsTouch = w;
    ad.overlayTouchRootVC = vc;

    [w makeKeyAndVisible];   // 与参照实现一致：触摸悬浮窗持 key，保证接收触摸
    [ad markSceneConnected:ad.touchSceneIdentifier];
    NSLog(@"[EdgeVolume] scene touch layer created");
}

/// 创建绑定全局前台场景的穿透层（HUD 提示）。
- (void)createScenePassLayerWithWindowScene:(UIWindowScene *)windowScene appDelegate:(AppDelegate *)ad {
    OverlayRootViewController *vc = [[OverlayRootViewController alloc] initWithMode:OverlayModePass];
    PassThroughWindow *w = [[PassThroughWindow alloc] initWithWindowScene:windowScene];
    w.backgroundColor = [UIColor clearColor];
    w.windowLevel = 9999;
    w.rootViewController = vc;
    self.window = w;

    ad.scenePassWindow = w;
    ad.scenePassVC = vc;
    ad.scenePassLayerCreated = YES;
    // 活跃层切换到场景层（HUD 经此访问）
    ad.overlayWindowNoTouch = w;
    ad.overlayPassRootVC = vc;

    [w setHidden:NO];        // HUD 窗不抢 key
    [ad markSceneConnected:ad.passSceneIdentifier];
    NSLog(@"[EdgeVolume] scene pass layer created");
}

- (void)setupOrientationObserver {
    if (self.orientationObserver) return;
    self.orientationObserver = [FBSOrientationObserver new];
    __weak SceneDelegate *weakSelf = self;
    [self.orientationObserver setHandler:^(FBSOrientationUpdate *update) {
        dispatch_async(dispatch_get_main_queue(), ^{
            SceneDelegate *strongSelf = weakSelf;
            if (!strongSelf) return;
            [strongSelf.window _rotateWindowToOrientation:update.orientation
                                          updateStatusBar:YES
                                                   duration:update.duration
                                              skipCallbacks:NO];
            [[NSNotificationCenter defaultCenter] postNotificationName:kEVFloatingWindowDidRotateNotification object:nil];
        });
    }];
}

- (void)sceneDidDisconnect:(UIScene *)scene {
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    NSString *ident = scene.session.persistentIdentifier;
    [ad markSceneDisconnected:ident];
    NSLog(@"[EdgeVolume] scene disconnected: %@", ident);
}

- (void)sceneDidBecomeActive:(UIScene *)scene {
    // 打开 App 时自动恢复被长按隐藏的悬浮窗。
    // 只对主界面场景生效（用实例标志判断，避免悬浮场景激活时误恢复）
    if (self.isMainScene && [EVSettings shared].overlayEnabled) {
        AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
        [ad setOverlayHidden:NO];
    }
}

- (void)sceneWillResignActive:(UIScene *)scene {
}

- (void)sceneWillEnterForeground:(UIScene *)scene {
}

- (void)sceneDidEnterBackground:(UIScene *)scene {
}

@end
