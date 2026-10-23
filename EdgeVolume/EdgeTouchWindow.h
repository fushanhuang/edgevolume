#import <UIKit/UIKit.h>

/// 全局悬浮「触摸窗口」：只有滑条自身声明的区域接收触摸，
/// 窗口内其余位置 hitTest 返回 nil，触摸继续下落到下层窗口
/// （其他 App / 桌面），做到「只有音量条位置可触控」。
///
/// 背景：UIView 的 hitTest 默认行为是「窗口内无子视图命中时返回窗口本身」，
/// 这会把整个窗口区域的触摸都吞掉。这里把「窗口本身」转换为 nil。
@interface EdgeTouchWindow : UIWindow

@end
