#import "OverlayContainerView.h"

@implementation OverlayContainerView

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.interactiveSubview && !self.interactiveSubview.hidden && self.interactiveSubview.alpha > 0.01) {
        CGPoint p = [self.interactiveSubview convertPoint:point fromView:self];
        if (!CGRectContainsPoint(CGRectInset(self.interactiveSubview.bounds, -16.0, -16.0), p)) {
            return nil; // 穿透
        }
    }
    return [super hitTest:point withEvent:event];
}

@end
