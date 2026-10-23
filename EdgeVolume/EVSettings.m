#import "EVSettings.h"

NSString *const kEVSettingsChangedNotification = @"EVSettingsChangedNotification";

@implementation EVSettings

+ (instancetype)shared {
    static EVSettings *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [EVSettings new]; });
    return s;
}

- (void)registerDefaults {
    NSDictionary *defs = @{
        @"EVEnabled": @YES,
        @"EVOverlayEnabled": @YES,
        @"EVEdge": @(EVEdgeRight),
        @"EVCenterYFraction": @(0.45),
        @"EVTrackLength": @(180.0),
        @"EVTrackThickness": @(20.0),
        @"EVTouchWidth": @(44.0),
        @"EVTrackAlpha": @(0.55),
        @"EVLockPosition": @NO,
        @"EVSmallWindowMode": @YES,
        @"EVKeepAlive": @YES,
        @"EVVolumeCategory": @(0),
        @"EVKBEnabled": @YES,
        @"EVKBUpModifier": @(EVKBModifierOption),
        @"EVKBUpKey": @(EVKBKeyPlus),
        @"EVKBDownModifier": @(EVKBModifierOption),
        @"EVKBDownKey": @(EVKBKeyMinus),
        @"EVKBStep": @(0.10),
        @"EVKBDiagnostic": @NO,
    };
    [[NSUserDefaults standardUserDefaults] registerDefaults:defs];
}

#pragma mark - getters / setters

- (BOOL)enabled { return [[NSUserDefaults standardUserDefaults] boolForKey:@"EVEnabled"]; }
- (void)setEnabled:(BOOL)v { [[NSUserDefaults standardUserDefaults] setBool:v forKey:@"EVEnabled"]; [self postChanged]; }

- (BOOL)overlayEnabled { return [[NSUserDefaults standardUserDefaults] boolForKey:@"EVOverlayEnabled"]; }
- (void)setOverlayEnabled:(BOOL)v { [[NSUserDefaults standardUserDefaults] setBool:v forKey:@"EVOverlayEnabled"]; [self postChanged]; }

- (EVEdge)edge { return (EVEdge)[[NSUserDefaults standardUserDefaults] integerForKey:@"EVEdge"]; }
- (void)setEdge:(EVEdge)v { [[NSUserDefaults standardUserDefaults] setInteger:v forKey:@"EVEdge"]; [self postChanged]; }

- (CGFloat)centerYFraction { return [[NSUserDefaults standardUserDefaults] doubleForKey:@"EVCenterYFraction"]; }
- (void)setCenterYFraction:(CGFloat)v {
    v = fmax(0.0, fmin(1.0, v));
    [[NSUserDefaults standardUserDefaults] setDouble:v forKey:@"EVCenterYFraction"];
    [self postChanged];
}

- (CGFloat)trackLength { return [[NSUserDefaults standardUserDefaults] doubleForKey:@"EVTrackLength"]; }
- (void)setTrackLength:(CGFloat)v {
    v = fmax(80.0, fmin(320.0, v));
    [[NSUserDefaults standardUserDefaults] setDouble:v forKey:@"EVTrackLength"];
    [self postChanged];
}

- (CGFloat)trackThickness { return [[NSUserDefaults standardUserDefaults] doubleForKey:@"EVTrackThickness"]; }
- (void)setTrackThickness:(CGFloat)v {
    v = fmax(10.0, fmin(44.0, v));
    [[NSUserDefaults standardUserDefaults] setDouble:v forKey:@"EVTrackThickness"];
    [self postChanged];
}

- (CGFloat)touchWidth { return [[NSUserDefaults standardUserDefaults] doubleForKey:@"EVTouchWidth"]; }
- (void)setTouchWidth:(CGFloat)v {
    v = fmax(26.0, fmin(120.0, v));
    [[NSUserDefaults standardUserDefaults] setDouble:v forKey:@"EVTouchWidth"];
    [self postChanged];
}

- (CGFloat)trackAlpha { return [[NSUserDefaults standardUserDefaults] doubleForKey:@"EVTrackAlpha"]; }
- (void)setTrackAlpha:(CGFloat)v {
    v = fmax(0.05, fmin(1.0, v));
    [[NSUserDefaults standardUserDefaults] setDouble:v forKey:@"EVTrackAlpha"];
    [self postChanged];
}

- (BOOL)lockPosition { return [[NSUserDefaults standardUserDefaults] boolForKey:@"EVLockPosition"]; }
- (void)setLockPosition:(BOOL)v { [[NSUserDefaults standardUserDefaults] setBool:v forKey:@"EVLockPosition"]; [self postChanged]; }

- (BOOL)smallWindowMode { return [[NSUserDefaults standardUserDefaults] boolForKey:@"EVSmallWindowMode"]; }
- (void)setSmallWindowMode:(BOOL)v { [[NSUserDefaults standardUserDefaults] setBool:v forKey:@"EVSmallWindowMode"]; [self postChanged]; }

- (BOOL)keepAlive { return [[NSUserDefaults standardUserDefaults] boolForKey:@"EVKeepAlive"]; }
- (void)setKeepAlive:(BOOL)v { [[NSUserDefaults standardUserDefaults] setBool:v forKey:@"EVKeepAlive"]; [self postChanged]; }

- (NSInteger)volumeCategory { return [[NSUserDefaults standardUserDefaults] integerForKey:@"EVVolumeCategory"]; }
- (void)setVolumeCategory:(NSInteger)v { [[NSUserDefaults standardUserDefaults] setInteger:v forKey:@"EVVolumeCategory"]; [self postChanged]; }

- (BOOL)kbEnabled { return [[NSUserDefaults standardUserDefaults] boolForKey:@"EVKBEnabled"]; }
- (void)setKbEnabled:(BOOL)v { [[NSUserDefaults standardUserDefaults] setBool:v forKey:@"EVKBEnabled"]; [self postChanged]; }

- (EVKBModifier)kbUpModifier { return (EVKBModifier)[[NSUserDefaults standardUserDefaults] integerForKey:@"EVKBUpModifier"]; }
- (void)setKbUpModifier:(EVKBModifier)v {
    v = (EVKBModifier)fmax(0, fmin(4, (NSInteger)v));
    [[NSUserDefaults standardUserDefaults] setInteger:v forKey:@"EVKBUpModifier"];
    [self postChanged];
}

- (EVKBKey)kbUpKey { return (EVKBKey)[[NSUserDefaults standardUserDefaults] integerForKey:@"EVKBUpKey"]; }
- (void)setKbUpKey:(EVKBKey)v {
    v = (EVKBKey)fmax(0, fmin(3, (NSInteger)v));
    [[NSUserDefaults standardUserDefaults] setInteger:v forKey:@"EVKBUpKey"];
    [self postChanged];
}

- (EVKBModifier)kbDownModifier { return (EVKBModifier)[[NSUserDefaults standardUserDefaults] integerForKey:@"EVKBDownModifier"]; }
- (void)setKbDownModifier:(EVKBModifier)v {
    v = (EVKBModifier)fmax(0, fmin(4, (NSInteger)v));
    [[NSUserDefaults standardUserDefaults] setInteger:v forKey:@"EVKBDownModifier"];
    [self postChanged];
}

- (EVKBKey)kbDownKey { return (EVKBKey)[[NSUserDefaults standardUserDefaults] integerForKey:@"EVKBDownKey"]; }
- (void)setKbDownKey:(EVKBKey)v {
    v = (EVKBKey)fmax(0, fmin(3, (NSInteger)v));
    [[NSUserDefaults standardUserDefaults] setInteger:v forKey:@"EVKBDownKey"];
    [self postChanged];
}

- (CGFloat)kbStep { return [[NSUserDefaults standardUserDefaults] doubleForKey:@"EVKBStep"]; }
- (void)setKbStep:(CGFloat)v {
    v = fmax(0.02, fmin(0.25, v));
    [[NSUserDefaults standardUserDefaults] setDouble:v forKey:@"EVKBStep"];
    [self postChanged];
}

- (BOOL)kbDiagnostic { return [[NSUserDefaults standardUserDefaults] boolForKey:@"EVKBDiagnostic"]; }
- (void)setKbDiagnostic:(BOOL)v { [[NSUserDefaults standardUserDefaults] setBool:v forKey:@"EVKBDiagnostic"]; [self postChanged]; }

- (NSString *)volumeCategoryString {
    return self.volumeCategory == 1 ? @"Ringtone" : @"Audio/Video";
}

- (void)postChanged {
    [[NSNotificationCenter defaultCenter] postNotificationName:kEVSettingsChangedNotification object:nil];
}

@end
