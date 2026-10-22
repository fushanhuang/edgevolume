#import <UIKit/UIKit.h>

/// 调节音量时浮现的小提示（放在穿透窗口中，不拦截触摸）
@interface VolumeHUDView : UIView

- (void)updateVolume:(float)volume;
- (void)show;
- (void)hideAfterDelay:(NSTimeInterval)delay;

@end
