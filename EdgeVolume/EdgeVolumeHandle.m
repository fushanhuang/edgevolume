#import "EdgeVolumeHandle.h"
#import "EVSettings.h"
#import "VolumeController.h"

@interface EdgeVolumeHandle ()
@property (nonatomic, strong) UIView *trackView;
@property (nonatomic, strong) UIView *fillView;
@property (nonatomic, strong) UIView *gripView;
@property (nonatomic, strong) UIPanGestureRecognizer *pan;
@property (nonatomic, strong) UILongPressGestureRecognizer *longPress;
@property (nonatomic, assign) float startVolume;
@property (nonatomic, assign) CGPoint startPoint;
@property (nonatomic, assign) BOOL moved;
@property (nonatomic, assign) BOOL moveMode;
@property (nonatomic, assign) BOOL longPressFired;
@property (nonatomic, readwrite) BOOL interacting;
@end

@implementation EdgeVolumeHandle

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _volume = -1.0f;
        self.backgroundColor = [UIColor clearColor];
        self.clipsToBounds = NO;

        _trackView = [[UIView alloc] init];
        _trackView.layer.cornerRadius = 5.0;
        _trackView.layer.borderWidth = 0.5;
        _trackView.userInteractionEnabled = NO;
        [self addSubview:_trackView];

        _fillView = [[UIView alloc] init];
        _fillView.layer.cornerRadius = 5.0;
        _fillView.userInteractionEnabled = NO;
        [_trackView addSubview:_fillView];

        _gripView = [[UIView alloc] init];
        _gripView.layer.cornerRadius = 3.0;
        _gripView.userInteractionEnabled = NO;
        [_trackView addSubview:_gripView];

        _pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        _pan.maximumNumberOfTouches = 1;
        _pan.minimumNumberOfTouches = 1;
        [self addGestureRecognizer:_pan];

        // 长按 = 紧急隐藏悬浮窗（万一悬浮窗显示异常，用户有办法收回控制权）
        _longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
        _longPress.minimumPressDuration = 0.7;
        _longPress.allowableMovement = 12.0;
        [self addGestureRecognizer:_longPress];

        [self refreshAppearance];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat trackW = 10.0;
    CGFloat pad = (CGRectGetWidth(self.bounds) - trackW) / 2.0;
    self.trackView.frame = CGRectMake(pad, 0.0, trackW, CGRectGetHeight(self.bounds));
    [self layoutFill];
    self.gripView.frame = CGRectMake((trackW - 6.0) / 2.0,
                                     (CGRectGetHeight(self.bounds) - 6.0) / 2.0,
                                     6.0, 6.0);
}

- (void)layoutFill {
    float v = self.volume < 0.0f ? 0.0f : self.volume;
    CGFloat h = CGRectGetHeight(self.trackView.bounds);
    CGFloat w = CGRectGetWidth(self.trackView.bounds);
    self.fillView.frame = CGRectMake(0.0, h * (1.0 - v), w, h * v);
}

- (void)setVolume:(float)volume {
    _volume = volume;
    [self layoutFill];
}

#pragma mark - 外观

- (void)refreshAppearance {
    CGFloat a = [EVSettings shared].trackAlpha;
    if (self.interacting) a = fmin(1.0, a + 0.35);
    self.trackView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.14 * a];
    self.trackView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.35 * a].CGColor;
    self.fillView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.45 * a];
    self.gripView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.55 * a];
    self.alpha = [EVSettings shared].enabled ? 1.0 : 0.0;
}

#pragma mark - 手势

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint loc = [pan locationInView:self.window];
    CGPoint origin = self.window.frame.origin;

    switch (pan.state) {
        case UIGestureRecognizerStateBegan: {
            _startPoint = loc;
            _startVolume = (self.volume >= 0.0f) ? self.volume : [VolumeController shared].volume;
            _moved = NO;
            _moveMode = NO;
            self.interacting = YES;
            [self refreshAppearance];
            break;
        }
        case UIGestureRecognizerStateChanged: {
            CGPoint trans = [pan translationInView:self.window];
            if (!_moveMode && fabs(trans.x) > 24.0 && fabs(trans.x) > fabs(trans.y)) {
                _moveMode = YES;   // 横向拖动进入移动模式
            }
            if (_moveMode) {
                CGPoint onScreen = CGPointMake(loc.x + origin.x, loc.y + origin.y);
                if (self.onMoveMoved) self.onMoveMoved(onScreen);
            } else {
                CGFloat delta = (_startPoint.y - loc.y) / (CGFloat)fmax(1.0, CGRectGetHeight(self.bounds));
                float v = fmaxf(0.0f, fminf(1.0f, _startVolume + (float)delta));
                if (fabsf(v - self.volume) > 0.0005f || self.volume < 0.0f) {
                    self.volume = v;
                    [[VolumeController shared] applyVolume:v];
                    if (self.onVolumeChanged) self.onVolumeChanged(v);
                }
                if (fabs(trans.x) > 4.0 || fabs(trans.y) > 4.0) _moved = YES;
            }
            break;
        }
        default: {
            self.interacting = NO;
            [self refreshAppearance];
            if (_longPressFired) {
                _longPressFired = NO;   // 长按已触发隐藏，不再当作点击
            } else if (_moveMode) {
                if (self.onMoveEnded) self.onMoveEnded();
            } else if (!_moved) {
                if (self.onTap) self.onTap();
            }
            _moveMode = NO;
            break;
        }
    }
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)lp {
    if (lp.state != UIGestureRecognizerStateBegan) return;
    _longPressFired = YES;
    _moveMode = NO;
    if (self.onLongPress) self.onLongPress();
}

@end
