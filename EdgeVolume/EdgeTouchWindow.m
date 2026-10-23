#import "EdgeTouchWindow.h"

@implementation EdgeTouchWindow

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
