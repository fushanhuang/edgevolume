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

- (BOOL)applyViaMPVolumeView:(float)v;
- (UISlider *)volumeSlider;
- (NSURL *)silentWAVURL;
- (void)postBackendChanged;
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
    NSError *err = nil;
    if (![EVSettings shared].keepAlive) {
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
    NSError *err = nil;
    if (enabled) {
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
    } else {
        [self.silentPlayer pause];
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient
                                         withOptions:AVAudioSessionCategoryOptionMixWithOthers
                                               error:&err];
        [[AVAudioSession sharedInstance] setActive:YES error:&err];
    }
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
}

@end
