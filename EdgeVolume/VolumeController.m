#import "VolumeController.h"
#import "EVSettings.h"
#import "AVSystemController.h"
#import "AppDelegate.h"
#import <MediaPlayer/MediaPlayer.h>

NSString *const kEVVolumeBackendChangedNotification = @"EVVolumeBackendChangedNotification";
NSString *const kEVSystemVolumeChangedNotification = @"EVSystemVolumeChangedNotification";

@interface VolumeController ()
@property (nonatomic, readwrite) float volume;
@property (nonatomic, readwrite) EVVolumeBackend backend;
@property (nonatomic, strong) MPVolumeView *volumeView;
@property (nonatomic, strong) AVAudioPlayer *silentPlayer;
@property (nonatomic, assign) BOOL observing;
@property (nonatomic, assign) BOOL applying;
@property (nonatomic, assign) BOOL keepAliveWanted;      // 用户是否开启了保活
@property (nonatomic, assign) BOOL sessionInterrupted;   // 音频会话是否被其他 App 抢占
@property (nonatomic, strong) NSTimer *keepAliveWatchdog;

- (BOOL)applyViaMPVolumeView:(float)v;
- (UISlider *)volumeSlider;
- (NSURL *)silentWAVURL;
- (void)postBackendChanged;
- (void)installAudioSessionObservers;
- (void)handleAudioSessionInterruption:(NSNotification *)note;
- (void)handleMediaServicesWereLost:(NSNotification *)note;
- (void)handleRouteChange:(NSNotification *)note;
- (void)handleSecondaryAudioHint:(NSNotification *)note;
- (void)handleWillEnterForeground:(NSNotification *)note;
- (void)startKeepAliveWatchdog;
@end

@implementation VolumeController

+ (instancetype)shared {
    static VolumeController *c;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ c = [VolumeController new]; });
    return c;
}

#pragma mark - 设置音量

- (void)applyVolume:(float)v {
    v = fmaxf(0.0f, fminf(1.0f, v));
    BOOL done = NO;

    // 1) 首选：Celestial 私有 API（不弹系统音量 HUD）
    Class cls = NSClassFromString(@"AVSystemController");
    if (cls) {
        if ([cls instancesRespondToSelector:@selector(setVolumeTo:forCategory:)]) {
            AVSystemController *avsc = [cls sharedAVSystemController];
            if (avsc && [avsc respondsToSelector:@selector(setVolumeTo:forCategory:)]) {
                self.applying = YES;
                done = [avsc setVolumeTo:v forCategory:[EVSettings shared].volumeCategoryString];
                self.applying = NO;
                if (done && self.backend != EVVolumeBackendAVSystemController) {
                    self.backend = EVVolumeBackendAVSystemController;
                    [self postBackendChanged];
                }
            }
        }
    }

    // 2) 兜底：MPVolumeView 的隐藏 slider
    if (!done) {
        done = [self applyViaMPVolumeView:v];
        if (done && self.backend != EVVolumeBackendMPVolumeView) {
            self.backend = EVVolumeBackendMPVolumeView;
            [self postBackendChanged];
        }
    }

    if (done) {
        self.volume = v;
        // 广播一次，让悬浮条/设置页同步刷新。
        // （KVO 回调里有 applying 抑制，自身路径不会重复收到。）
        [[NSNotificationCenter defaultCenter] postNotificationName:kEVSystemVolumeChangedNotification
                                                            object:nil
                                                          userInfo:@{@"volume": @(v)}];
    }
}

- (BOOL)applyViaMPVolumeView:(float)v {
    UISlider *slider = [self volumeSlider];
    if (!slider) return NO;
    self.applying = YES;
    slider.value = v;
    [slider sendActionsForControlEvents:UIControlEventTouchUpInside];
    self.applying = NO;
    return YES;
}

#pragma mark - 读取音量

- (float)readCurrentVolume {
    UISlider *slider = [self volumeSlider];
    if (slider) {
        self.volume = slider.value;
        return slider.value;
    }
    float v = [AVAudioSession sharedInstance].outputVolume;
    self.volume = v;
    return v;
}

- (UISlider *)volumeSlider {
    [self ensureVolumeView];
    if (!self.volumeView) return nil;
    for (UIView *sub in self.volumeView.subviews) {
        if ([sub isKindOfClass:[UISlider class]]) {
            return (UISlider *)sub;
        }
    }
    return nil;
}

- (void)ensureVolumeView {
    if (self.volumeView && self.volumeView.window) return;
    UIWindow *host = nil;
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    if ([ad isKindOfClass:NSClassFromString(@"AppDelegate")] && ad.window) {
        host = ad.window;
    }
    if (!host) host = [UIApplication sharedApplication].keyWindow;
    if (!host) return;
    if (!self.volumeView) {
        MPVolumeView *vv = [[MPVolumeView alloc] initWithFrame:CGRectZero];
        vv.showsRouteButton = NO;
        vv.userInteractionEnabled = NO;
        self.volumeView = vv;
    }
    [host addSubview:self.volumeView];
}

#pragma mark - 监听系统音量变化

- (void)startMonitoring {
    [self ensureVolumeView];
    if (!self.observing) {
        [[AVAudioSession sharedInstance] addObserver:self
                                         forKeyPath:@"outputVolume"
                                            options:NSKeyValueObservingOptionNew
                                                context:nil];
        self.observing = YES;
    }
    [self installAudioSessionObservers];
    NSError *err = nil;
    if (![EVSettings shared].keepAlive) {
        self.keepAliveWanted = NO;
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient
                                         withOptions:AVAudioSessionCategoryOptionMixWithOthers
                                               error:&err];
        [[AVAudioSession sharedInstance] setActive:YES error:&err];
    } else {
        [self setKeepAliveEnabled:YES];
    }
    self.volume = [self readCurrentVolume];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(void *)context {
    if (![keyPath isEqualToString:@"outputVolume"]) return;
    float v = [[change objectForKey:NSKeyValueChangeNewKey] floatValue];
    if (self.applying) {
        self.volume = v;
        return;
    }
    if (fabsf(v - self.volume) > 0.001f) {
        self.volume = v;
        [[NSNotificationCenter defaultCenter] postNotificationName:kEVSystemVolumeChangedNotification
                                                            object:nil
                                                          userInfo:@{@"volume": @(v)}];
        if (self.systemVolumeChanged) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.systemVolumeChanged) self.systemVolumeChanged(v);
            });
        }
    }
}

#pragma mark - 后台保活（静音循环播放）

- (void)setKeepAliveEnabled:(BOOL)enabled {
    self.keepAliveWanted = enabled;
    if (!enabled) {
        [self.keepAliveWatchdog invalidate];
        self.keepAliveWatchdog = nil;
        self.sessionInterrupted = NO;
        [self.silentPlayer pause];
        NSError *err = nil;
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient
                                         withOptions:AVAudioSessionCategoryOptionMixWithOthers
                                               error:&err];
        [[AVAudioSession sharedInstance] setActive:YES error:&err];
        return;
    }
    [self activateKeepAliveSession];
    [self startKeepAliveWatchdog];
}

/// 建立并激活后台播放会话 + 启动静音循环播放（幂等）
- (void)activateKeepAliveSession {
    NSError *err = nil;
    // 先停再建：被其他 App 抢占后直接 setCategory 可能失败，deactivate 后重建更稳
    [[AVAudioSession sharedInstance] setActive:NO error:&err];
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback
                                     withOptions:AVAudioSessionCategoryOptionMixWithOthers
                                           error:&err];
    [[AVAudioSession sharedInstance] setActive:YES error:&err];
    if (!self.silentPlayer) {
        NSURL *url = [self silentWAVURL];
        if (url) {
            self.silentPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&err];
            self.silentPlayer.numberOfLoops = -1;
            self.silentPlayer.volume = 0.0;
            [self.silentPlayer prepareToPlay];
        }
    }
    [self.silentPlayer play];
    self.sessionInterrupted = NO;
}

/// 保活健康度：会话是 Playback 类别且播放器在播放（诊断用）
- (BOOL)keepAliveHealthy {
    if (!self.keepAliveWanted) return NO;
    return [[AVAudioSession sharedInstance] category] == AVAudioSessionCategoryPlayback
        && self.silentPlayer.isPlaying;
}

/// 尝试恢复保活（幂等；中断结束、切回前台、看门狗自愈时调用）
- (void)restoreKeepAliveIfNeeded {
    if (!self.keepAliveWanted) return;
    if ([[AVAudioSession sharedInstance] category] == AVAudioSessionCategoryPlayback
        && self.silentPlayer.isPlaying) {
        return; // 健康，无需动作
    }
    [self activateKeepAliveSession];
}

#pragma mark - 音频会话事件（被抖音等 App 抢占后的恢复）

- (void)installAudioSessionObservers {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(handleAudioSessionInterruption:)
               name:AVAudioSessionInterruptionNotification object:nil];
    [nc addObserver:self selector:@selector(handleMediaServicesWereLost:)
               name:AVAudioSessionMediaServicesWereLostNotification object:nil];
    [nc addObserver:self selector:@selector(handleRouteChange:)
               name:AVAudioSessionRouteChangeNotification object:nil];
    [nc addObserver:self selector:@selector(handleSecondaryAudioHint:)
               name:AVAudioSessionSilenceSecondaryAudioHintNotification object:nil];
    [nc addObserver:self selector:@selector(handleWillEnterForeground:)
               name:UIApplicationWillEnterForegroundNotification object:nil];
}

- (void)handleAudioSessionInterruption:(NSNotification *)note {
    NSDictionary *info = note.userInfo;
    NSUInteger type = [info[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    if (type == AVAudioSessionInterruptionTypeBegan) {
        // 被其他 App（如抖音）抢占。不停播放器——保持 playback 资格，
        // 尽量缩短进程被系统挂起的窗口；是否真正恢复以 ended 为准
        self.sessionInterrupted = YES;
    } else {
        // 结束：立即重建会话并恢复静音播放（不依赖 ShouldResume 标志，
        // 部分机型的电话/Siri 类打断该标志缺失，但保活仍应恢复）
        self.sessionInterrupted = NO;
        if (self.keepAliveWanted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self activateKeepAliveSession];
            });
        }
    }
}

- (void)handleMediaServicesWereLost:(NSNotification *)note {
    self.sessionInterrupted = YES;
    [self.silentPlayer pause];
}

- (void)handleRouteChange:(NSNotification *)note {
    // 耳机拔掉/路由变化不会杀会话，这里只做状态刷新；播放器若停了由看门狗恢复
    if (self.keepAliveWanted && !self.silentPlayer.isPlaying && !self.sessionInterrupted) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self restoreKeepAliveIfNeeded];
        });
    }
}

- (void)handleSecondaryAudioHint:(NSNotification *)note {
    // 其他 App 开始播放，我们被降为 secondary。不能停（停了进程会被挂起），
    // 保持静音循环继续跑即可——这正是 MixWithOthers 的意义
    if (self.keepAliveWanted && !self.silentPlayer.isPlaying) {
        [self.silentPlayer play];
    }
}

- (void)handleWillEnterForeground:(NSNotification *)note {
    [self restoreKeepAliveIfNeeded];
}

/// 后台自愈看门狗：后台 running 状态下定时检查播放器是否还活着。
/// 注意：若进程已被系统挂起，定时器本身也不会触发——防挂起主要靠
/// audio background mode + interruption 及时恢复，看门狗是第二道防线
- (void)startKeepAliveWatchdog {
    [self.keepAliveWatchdog invalidate];
    self.keepAliveWatchdog = [NSTimer scheduledTimerWithTimeInterval:20.0
                                                              target:self
                                                            selector:@selector(keepAliveWatchdogFired:)
                                                            userInfo:nil
                                                             repeats:YES];
}

- (void)keepAliveWatchdogFired:(NSTimer *)timer {
    if (!self.keepAliveWanted) return;
    [self restoreKeepAliveIfNeeded];
}

/// 生成一段 1 秒的静音 WAV（8kHz / 16bit / 单声道）
- (NSURL *)silentWAVURL {
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"ev_silence.wav"];
    NSURL *url = [NSURL fileURLWithPath:path];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) return url;

    const uint32_t sampleRate = 8000;
    const uint16_t channels = 1;
    const uint16_t bits = 16;
    const uint32_t dataSize = sampleRate * channels * (bits / 8);

    NSMutableData *d = [NSMutableData dataWithCapacity:44 + dataSize];
    [d appendBytes:"RIFF" length:4];
    uint32_t chunkSize = 36 + dataSize;
    [d appendBytes:&chunkSize length:4];
    [d appendBytes:"WAVE" length:4];
    [d appendBytes:"fmt " length:4];
    uint32_t subchunk1 = 16;
    [d appendBytes:&subchunk1 length:4];
    uint16_t audioFormat = 1;
    [d appendBytes:&audioFormat length:2];
    [d appendBytes:&channels length:2];
    [d appendBytes:&sampleRate length:4];
    uint32_t byteRate = sampleRate * channels * (bits / 8);
    [d appendBytes:&byteRate length:4];
    uint16_t blockAlign = channels * (bits / 8);
    [d appendBytes:&blockAlign length:2];
    [d appendBytes:&bits length:2];
    [d appendBytes:"data" length:4];
    [d appendBytes:&dataSize length:4];
    NSData *silence = [NSMutableData dataWithLength:dataSize];
    [d appendData:silence];

    if (![d writeToURL:url atomically:YES]) return nil;
    return url;
}

#pragma mark - 通知

- (void)postBackendChanged {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:kEVVolumeBackendChangedNotification object:nil];
    });
}

- (void)dealloc {
    if (self.observing) {
        [[AVAudioSession sharedInstance] removeObserver:self forKeyPath:@"outputVolume"];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
