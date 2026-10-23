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
@end

@implementation SceneDelegate

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    if (![scene isKindOfClass:[UIWindowScene class]]) return;
    UIWindowScene *windowScene = (UIWindowScene *)scene;
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    NSString *ident = session.persistentIdentifier;

    if ([ident isEqualToString:ad.touchSceneIdentifier]) {
        // ===== 全局可触摸悬浮场景（音量滑动条）=====
        UIWindow *placeholder = ad.overlayWindowIsTouch;
        // EdgeTouchWindow：窗口内非滑条区域 hitTest 返回 nil，触摸穿透到下层
        EdgeTouchWindow *w = [[EdgeTouchWindow alloc] initWithWindowScene:windowScene];
        w.backgroundColor = [UIColor clearColor];
        w.windowLevel = 10000;
        w.rootViewController = ad.overlayTouchRootVC;
        self.window = w;
        ad.overlayWindowIsTouch = w;
        placeholder.hidden = YES;
        [w makeKeyAndVisible];   // 与参照实现一致：触摸悬浮窗持 key，保证接收触摸
        [ad markSceneConnected:ad.touchSceneIdentifier];
        NSLog(@"[EdgeVolume] touch overlay scene connected");
    }
    else if ([ident isEqualToString:ad.passSceneIdentifier]) {
        // ===== 全局穿透悬浮场景（HUD）=====
        UIWindow *placeholder = ad.overlayWindowNoTouch;
        PassThroughWindow *w = [[PassThroughWindow alloc] initWithWindowScene:windowScene];
        w.backgroundColor = [UIColor clearColor];
        w.windowLevel = 9999;
        w.rootViewController = ad.overlayPassRootVC;
        self.window = w;
        ad.overlayWindowNoTouch = w;
        placeholder.hidden = YES;
        [w setHidden:NO];        // HUD 窗不抢 key
        [ad markSceneConnected:ad.passSceneIdentifier];
        NSLog(@"[EdgeVolume] pass-through overlay scene connected");
    }
    else {
        // ===== 应用主界面（设置页）=====
        self.window = [[UIWindow alloc] initWithWindowScene:windowScene];
        SettingsViewController *settings = [[SettingsViewController alloc] initWithStyle:UITableViewStyleGrouped];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:settings];
        self.window.rootViewController = nav;
        [self.window makeKeyAndVisible];
        ad.window = self.window;
        [[VolumeController shared] ensureVolumeView];
    }

    // 所有场景统一帧（与参照实现一致）
    self.window.frame = windowScene.coordinateSpace.bounds;

    // 悬浮窗跟随设备旋转
    if ([ident isEqualToString:ad.touchSceneIdentifier] || [ident isEqualToString:ad.passSceneIdentifier]) {
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
}

- (void)sceneDidDisconnect:(UIScene *)scene {
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    NSString *ident = scene.session.persistentIdentifier;
    [ad markSceneDisconnected:ident];
    NSLog(@"[EdgeVolume] scene disconnected: %@", ident);
}

- (void)sceneDidBecomeActive:(UIScene *)scene {
    // 打开 App 时自动恢复被长按隐藏的悬浮窗
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    NSString *ident = scene.session.persistentIdentifier;
    BOOL isOverlay = [ident isEqualToString:ad.touchSceneIdentifier] || [ident isEqualToString:ad.passSceneIdentifier];
    if (!isOverlay && [EVSettings shared].overlayEnabled) {
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
