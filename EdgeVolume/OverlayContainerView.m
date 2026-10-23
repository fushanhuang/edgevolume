#import "OverlayContainerView.h"

@implementation OverlayContainerView

// 触控规则：只有把手自身（即触控热区，宽度可在设置里调）接收触摸，
// 容器内其余位置以及容器外一律返回 nil 穿透到下层 App / 桌面。
// 注意：不能再给 bounds 外扩余量—— UIView 在无子视图命中时会返回
// 容器自身，那圈余量会把触摸吞掉，正是"屏幕点不动"类问题的来源。
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.interactiveSubview && !self.interactiveSubview.hidden && self.interactiveSubview.alpha > 0.01) {
        CGPoint p = [self.interactiveSubview convertPoint:point fromView:self];
        if (!CGRectContainsPoint(self.interactiveSubview.bounds, p)) {
            return nil; // 穿透
        }
    }
    return [super hitTest:point withEvent:event];
}

@end
