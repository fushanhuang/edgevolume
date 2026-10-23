#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

typedef NS_ENUM(NSInteger, EVVolumeBackend) {
    EVVolumeBackendUnknown = 0,
    EVVolumeBackendAVSystemController,   // 私有 API：静默设置，不弹系统 HUD（推荐）
    EVVolumeBackendMPVolumeView          // 公开 API 兜底
};

extern NSString *const kEVSystemVolumeChangedNotification;
extern NSString *const kEVVolumeBackendChangedNotification;

/// 系统音量控制：多路回退 + 后台保活 + 系统音量变化监听
@interface VolumeController : NSObject

+ (instancetype)shared;

/// 当前音量（0..1，缓存值，可能滞后）
@property (nonatomic, readonly) float volume;
/// 当前生效的后端
@property (nonatomic, readonly) EVVolumeBackend backend;

/// 设置系统音量（自动选择后端）
- (void)applyVolume:(float)volume;

/// 主动读取一次系统音量
- (float)readCurrentVolume;

/// 启动 outputVolume 监听（KVO）
- (void)startMonitoring;

/// 确保隐藏的 MPVolumeView 已挂到窗口上（读取/兜底设置用）
- (void)ensureVolumeView;

/// 后台静音播放保活（默认跟随设置）
- (void)setKeepAliveEnabled:(BOOL)enabled;

/// 保活是否健康（音频会话已激活且静音播放器在播放）。
/// 被其他 App（如抖音）抢占音频会话后会变 NO——此时 App 随时可能被
/// 系统挂起，后台快捷键会失效。诊断信息展示用
@property (nonatomic, readonly) BOOL keepAliveHealthy;

/// 尝试恢复保活（音频中断结束、切回前台时调用；幂等，安全频繁调用）
- (void)restoreKeepAliveIfNeeded;

/// 系统音量被其他途径改变（硬件按键、控制中心等）时回调，主线程调用
@property (nonatomic, copy) void (^systemVolumeChanged)(float volume);

@end
