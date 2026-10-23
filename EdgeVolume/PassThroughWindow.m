#import "PassThroughWindow.h"
#import <objc/runtime.h>

@implementation PassThroughWindow

// 保持窗口所在场景在 App 退到后台后依然存活（参照 FrontBoardAppLauncher）
- (BOOL)_extendsScreenSceneLifetime {
    return YES;
}

// 允许覆盖系统遮挡检测，配合 FBScene 的 ignoreOcclusionReasons=SystemApp
- (BOOL)_allowsOcclusionDetectionOverride {
    return YES;
}

// 双保险 1：UIKit 私有属性，让整个窗口忽略 hit-test（iOS 17 仍有效）
- (BOOL)_ignoresHitTest {
    return YES;
}

// 双保险 2：即使 _ignoresHitTest 在个别系统版本失效，
// hitTest 返回 nil 也能保证事件穿透到下层窗口。
// 该窗口只用于显示 HUD（无交互需求），因此整窗穿透是安全的。
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    return nil;
}

@end
