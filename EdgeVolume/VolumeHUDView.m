#import "VolumeHUDView.h"

@interface VolumeHUDView ()
@property (nonatomic, strong) UIView *box;
@property (nonatomic, strong) UIView *track;
@property (nonatomic, strong) UIView *fill;
@property (nonatomic, strong) UILabel *label;
@property (nonatomic, strong) NSTimer *hideTimer;
@end

@implementation VolumeHUDView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
        self.alpha = 0.0;

        _box = [[UIView alloc] init];
        _box.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.55];
        _box.layer.cornerRadius = 14.0;
        _box.userInteractionEnabled = NO;
        [self addSubview:_box];

        _track = [[UIView alloc] init];
        _track.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.30];
        _track.layer.cornerRadius = 2.0;
        _track.userInteractionEnabled = NO;
        [_box addSubview:_track];

        _fill = [[UIView alloc] init];
        _fill.backgroundColor = [UIColor whiteColor];
        _fill.layer.cornerRadius = 2.0;
        _fill.userInteractionEnabled = NO;
        [_track addSubview:_fill];

        _label = [[UILabel alloc] init];
        _label.font = [UIFont systemFontOfSize:10.0 weight:UIFontWeightMedium];
        _label.textColor = [UIColor whiteColor];
        _label.textAlignment = NSTextAlignmentCenter;
        _label.userInteractionEnabled = NO;
        [_box addSubview:_label];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.box.frame = self.bounds;
    CGFloat trackW = 4.0;
    CGFloat trackH = 40.0;
    self.track.frame = CGRectMake((CGRectGetWidth(self.bounds) - trackW) / 2.0, 8.0, trackW, trackH);
    self.label.frame = CGRectMake(0.0, CGRectGetMaxY(self.track.frame) + 3.0,
                                  CGRectGetWidth(self.bounds), 14.0);
    [self layoutFill];
}

- (void)layoutFill {
    float v = fmaxf(0.0f, fminf(1.0f, self.fill.tag / 100.0f));
    CGFloat h = CGRectGetHeight(self.track.bounds);
    self.fill.frame = CGRectMake(0.0, h * (1.0 - v), CGRectGetWidth(self.track.bounds), h * v);
}

- (void)updateVolume:(float)volume {
    self.fill.tag = (NSInteger)lroundf(fmaxf(0.0f, fminf(1.0f, volume)) * 100.0f);
    self.label.text = [NSString stringWithFormat:@"%ld%%", (long)self.fill.tag];
    [self layoutFill];
}

- (void)show {
    [self.hideTimer invalidate];
    self.hideTimer = nil;
    self.hidden = NO;
    [UIView animateWithDuration:0.12 animations:^{
        self.alpha = 1.0;
    }];
}

- (void)hideAfterDelay:(NSTimeInterval)delay {
    [self.hideTimer invalidate];
    self.hideTimer = [NSTimer scheduledTimerWithTimeInterval:delay
                                                     target:self
                                                   selector:@selector(hide)
                                                   userInfo:nil
                                                    repeats:NO];
}

- (void)hide {
    [UIView animateWithDuration:0.25 animations:^{
        self.alpha = 0.0;
    }];
}

@end
