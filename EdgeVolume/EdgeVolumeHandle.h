#import <UIKit/UIKit.h>

/// 贴在屏幕边缘的透明音量滑动条
/// 手势：上下滑动=调节音量；左右拖动=移动位置；单击=显示当前音量
@interface EdgeVolumeHandle : UIView

/// 当前音量 0..1（<0 表示尚未初始化）
@property (nonatomic, assign) float volume;
/// 是否正在被触摸
@property (nonatomic, assign, readonly) BOOL interacting;

/// 音量变化（用户滑动触发）
@property (nonatomic, copy) void (^onVolumeChanged)(float volume);
/// 移动模式：期望的中心点（屏幕坐标）
@property (nonatomic, copy) void (^onMoveMoved)(CGPoint desiredScreenCenter);
/// 移动结束（需要吸附边缘）
@property (nonatomic, copy) void (^onMoveEnded)(void);
/// 单击
@property (nonatomic, copy) void (^onTap)(void);
/// 长按（紧急隐藏悬浮窗的逃生开关）
@property (nonatomic, copy) void (^onLongPress)(void);

/// 刷新外观（透明度/高亮）
- (void)refreshAppearance;

@end
