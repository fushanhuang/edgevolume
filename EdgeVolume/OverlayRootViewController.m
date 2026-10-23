#import "OverlayRootViewController.h"
#import "OverlayContainerView.h"
#import "EVSettings.h"
#import "VolumeController.h"
#import "AppDelegate.h"
#import "KeyboardShortcutController.h"

// 注意：kEVFloatingWindowDidRotateNotification 的定义在 SceneDelegate.m，
//       kEVSystemVolumeChangedNotification 的定义在 VolumeController.m，
//       本文件只通过 extern 声明使用，避免重复定义（duplicate symbol）。

@interface OverlayRootViewController ()
@property (nonatomic, assign) OverlayMode mode;
@property (nonatomic, strong) EdgeVolumeHandle *handle;
@property (nonatomic, strong) VolumeHUDView *hud;
@property (nonatomic, assign) CGPoint currentScreenCenter;

- (void)setupTouchMode;
- (void)applyOverlayLayoutAnimated:(BOOL)animated;
- (void)showHUDForVolume:(float)volume;
- (void)moveHandleToScreenCenter:(CGPoint)screenCenter;
- (void)finishMove;
@end

@implementation OverlayRootViewController

- (instancetype)initWithMode:(OverlayMode)mode {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _mode = mode;
    }
    return self;
}

- (void)loadView {
    OverlayContainerView *v = [[OverlayContainerView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    v.backgroundColor = [UIColor clearColor];
    self.view = v;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    if (self.mode == OverlayModeTouch) {
        [self setupTouchMode];
    }
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(settingsChanged:) name:kEVSettingsChangedNotification object:nil];
    [nc addObserver:self selector:@selector(windowDidRotate:) name:kEVFloatingWindowDidRotateNotification object:nil];
    [nc addObserver:self selector:@selector(systemVolumeChanged:) name:kEVSystemVolumeChangedNotification object:nil];
    [nc addObserver:self selector:@selector(keyboardVolumeAdjusted:) name:kEVKeyboardVolumeAdjustedNotification object:nil];
}

/// 硬件键盘快捷键触发：同步滑条位置并浮现 HUD（后台时同样有效）
- (void)keyboardVolumeAdjusted:(NSNotification *)note {
    if (self.mode != OverlayModeTouch) return;
    float v = [note.userInfo[@"volume"] floatValue];
    self.handle.volume = v;
    [self showHUDForVolume:v];
}

/// 前台快捷键（UIKeyCommand）：App 处于前台时由 UIKit 分发到这里，
/// 后台路径由 KeyboardShortcutController 的 IOHID 监听负责
- (NSArray<UIKeyCommand *> *)keyCommands {
    return [[KeyboardShortcutController shared] foregroundKeyCommands];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self applyOverlayLayoutAnimated:NO];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Touch 模式（滑动条）

- (void)setupTouchMode {
    self.handle = [[EdgeVolumeHandle alloc] initWithFrame:CGRectZero];
    ((OverlayContainerView *)self.view).interactiveSubview = self.handle;
    [self.view addSubview:self.handle];

    __weak OverlayRootViewController *weakSelf = self;
    self.handle.onVolumeChanged = ^(float volume) {
        [weakSelf showHUDForVolume:volume];
    };
    self.handle.onTap = ^{
        [weakSelf showHUDForVolume:[VolumeController shared].volume];
    };
    self.handle.onMoveMoved = ^(CGPoint desiredScreenCenter) {
        [weakSelf moveHandleToScreenCenter:desiredScreenCenter];
    };
    self.handle.onMoveEnded = ^{
        [weakSelf finishMove];
    };
    self.handle.onLongPress = ^{
        // 长按滑条：紧急隐藏全部悬浮窗（打开 App 自动恢复）
        AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
        [ad setOverlayHidden:YES];
    };

    [self applyOverlayLayoutAnimated:NO];
}

- (CGRect)floatingScreenBounds {
    if (self.view.window.screen) return self.view.window.screen.bounds;
    return [UIScreen mainScreen].bounds;
}

- (CGRect)targetHandleFrameInScreen {
    EVSettings *s = [EVSettings shared];
    CGRect bounds = [self floatingScreenBounds];
    // 把手宽度 = 触控热区宽度（可见轨道始终是其中 10pt，居中显示）
    CGFloat w = fmax(26.0, s.touchWidth);
    CGFloat h = s.trackLength;
    CGFloat sideMargin = 6.0;
    CGFloat x = (s.edge == EVEdgeRight) ? CGRectGetWidth(bounds) - w - sideMargin : sideMargin;
    CGFloat top = 40.0, bottom = 40.0;
    CGFloat usable = CGRectGetHeight(bounds) - top - bottom;
    if (usable < 60.0) { top = 8.0; bottom = 8.0; usable = CGRectGetHeight(bounds) - 16.0; }
    CGFloat cy = top + usable * s.centerYFraction;
    return CGRectMake(x, cy - h / 2.0, w, h);
}

- (void)applyOverlayLayoutAnimated:(BOOL)animated {
    if (self.mode != OverlayModeTouch) return;
    UIWindow *win = self.view.window;
    if (!win) return;
    EVSettings *s = [EVSettings shared];
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    // 总开关关闭、或长按紧急隐藏中：隐藏窗口（紧急隐藏打开 App 后自动解除）
    if (!s.enabled || ad.overlayHidden) {
        win.hidden = YES;
        return;
    }
    win.hidden = NO;

    CGRect target = [self targetHandleFrameInScreen];
    self.currentScreenCenter = CGPointMake(CGRectGetMidX(target), CGRectGetMidY(target));

    __weak OverlayRootViewController *weakSelf = self;
    void (^apply)(void) = ^{
        __strong OverlayRootViewController *strongSelf = weakSelf;
        if (!strongSelf) return;
        if ([EVSettings shared].smallWindowMode) {
            // 小窗模式：窗口恰好覆盖滑动条（含外扩），窗口之外的触摸 100% 穿透
            win.frame = CGRectInset(target, -14.0, -8.0);
            strongSelf.handle.frame = CGRectMake(14.0, 8.0, target.size.width, target.size.height);
        } else {
            // 全屏模式：窗口全屏，依靠 hitTest 穿透
            win.frame = [strongSelf floatingScreenBounds];
            strongSelf.handle.frame = target;
        }
    };
    if (animated) {
        [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:apply completion:nil];
    } else {
        apply();
    }
    [self.handle refreshAppearance];
}

- (void)moveHandleToScreenCenter:(CGPoint)screenCenter {
    if ([EVSettings shared].lockPosition) return;
    CGRect bounds = [self floatingScreenBounds];
    CGRect target = [self targetHandleFrameInScreen];
    CGFloat halfW = target.size.width / 2.0 + 14.0;
    CGFloat halfH = target.size.height / 2.0 + 8.0;
    CGFloat cx = fmax(halfW + 2.0, fmin(CGRectGetWidth(bounds) - halfW - 2.0, screenCenter.x));
    CGFloat cy = fmax(40.0 + halfH, fmin(CGRectGetHeight(bounds) - 40.0 - halfH, screenCenter.y));
    if ([EVSettings shared].smallWindowMode) {
        self.view.window.frame = CGRectMake(cx - halfW, cy - halfH, halfW * 2.0, halfH * 2.0);
    } else {
        self.handle.center = CGPointMake(cx, cy);
    }
    self.currentScreenCenter = CGPointMake(cx, cy);
}

- (void)finishMove {
    EVSettings *s = [EVSettings shared];
    CGRect bounds = [self floatingScreenBounds];
    s.edge = (self.currentScreenCenter.x < CGRectGetWidth(bounds) / 2.0) ? EVEdgeLeft : EVEdgeRight;
    CGFloat top = 40.0, bottom = 40.0;
    CGFloat usable = CGRectGetHeight(bounds) - top - bottom;
    if (usable > 0.0) {
        s.centerYFraction = (self.currentScreenCenter.y - top) / usable;
    }
    [self applyOverlayLayoutAnimated:YES];
}

#pragma mark - Pass 模式（HUD）

- (void)presentHUDWithVolume:(float)volume nearScreenPoint:(CGPoint)point {
    if (!self.hud) {
        self.hud = [[VolumeHUDView alloc] initWithFrame:CGRectMake(0.0, 0.0, 52.0, 76.0)];
        [self.view addSubview:self.hud];
    }
    CGRect bounds = self.view.bounds;
    CGPoint local = point;
    if (self.view.window) {
        local = CGPointMake(point.x - self.view.window.frame.origin.x,
                            point.y - self.view.window.frame.origin.y);
    }
    CGFloat w = 52.0, h = 76.0;
    CGFloat x = (local.x > CGRectGetWidth(bounds) / 2.0) ? (local.x - w - 44.0) : (local.x + 44.0);
    x = fmax(8.0, fmin(CGRectGetWidth(bounds) - w - 8.0, x));
    CGFloat y = fmax(8.0, fmin(CGRectGetHeight(bounds) - h - 8.0, local.y - h / 2.0));
    self.hud.frame = CGRectMake(x, y, w, h);
    [self.hud updateVolume:volume];
    [self.hud show];
    [self.hud hideAfterDelay:1.2];
}

- (void)showHUDForVolume:(float)volume {
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    if ([ad isKindOfClass:NSClassFromString(@"AppDelegate")]) {
        [(OverlayRootViewController *)ad.overlayPassRootVC presentHUDWithVolume:volume nearScreenPoint:self.currentScreenCenter];
    }
}

#pragma mark - 通知

- (void)settingsChanged:(NSNotification *)note {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self applyOverlayLayoutAnimated:NO];
    });
}

- (void)windowDidRotate:(NSNotification *)note {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self applyOverlayLayoutAnimated:NO];
    });
}

- (void)systemVolumeChanged:(NSNotification *)note {
    float v = [note.userInfo[@"volume"] floatValue];
    if (self.mode == OverlayModeTouch) {
        self.handle.volume = v;
    }
}

@end
