#import "EdgeTouchWindow.h"

@implementation EdgeTouchWindow

// 保持窗口所在场景在 App 退到后台后依然存活（参照 FrontBoardAppLauncher）。
// 悬浮 FBScene 标记了 foreground=YES，这个 hook 让 UIKit 不要随手收回场景。
- (BOOL)_extendsScreenSceneLifetime {
    return YES;
}

// 允许覆盖系统遮挡检测，配合 FBScene 的 ignoreOcclusionReasons=SystemApp，
// 使本窗口不被桌面/其他 App 的遮挡判定隐藏。
- (BOOL)_allowsOcclusionDetectionOverride {
    return YES;
}

// 关键：UIView 默认在「窗口内、无子视图命中」时返回窗口本身，
// 导致整个窗口区域的触摸被吞掉、下层 App / 桌面收不到事件。
// 这里把窗口自身转换为 nil，让系统继续向更低层的窗口做命中测试，
// 于是只有滑条（及其很小的抓取边距）是可触控的，其余全部穿透。
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    if (hit == self) return nil;
    return hit;
}

@end
