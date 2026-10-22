#import <UIKit/UIKit.h>

/// 悬浮窗根视图：全屏模式下，只有 interactiveSubview 所在区域（含 16pt 外扩）接收触摸，
/// 其余区域 hitTest 返回 nil，触摸穿透到下层的 App / 桌面
@interface OverlayContainerView : UIView

@property (nonatomic, weak) UIView *interactiveSubview;

@end
