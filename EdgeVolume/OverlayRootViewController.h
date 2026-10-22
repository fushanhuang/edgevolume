#import <UIKit/UIKit.h>
#import "EdgeVolumeHandle.h"
#import "VolumeHUDView.h"

typedef NS_ENUM(NSInteger, OverlayMode) {
    OverlayModeTouch = 0,   // 全局可触摸悬浮窗（放音量滑动条）
    OverlayModePass = 1     // 全局穿透悬浮窗（放 HUD 提示）
};

extern NSString *const kEVFloatingWindowDidRotateNotification;

/// 悬浮窗的根视图控制器（touch / pass 两种模式复用）
@interface OverlayRootViewController : UIViewController

- (instancetype)initWithMode:(OverlayMode)mode;

/// 在穿透窗中显示音量 HUD（屏幕坐标）
- (void)presentHUDWithVolume:(float)volume nearScreenPoint:(CGPoint)point;

@end
