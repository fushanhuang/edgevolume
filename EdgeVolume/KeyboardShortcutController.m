//
//  KeyboardShortcutController.m
//  EdgeVolume
//
//  硬件键盘快捷键调音量的后台监听实现。
//
//  工作原理：
//    1) dlopen IOKit.framework，运行时解析 IOHIDEventSystemClient*** 系列函数
//       （不链接私有框架，符号缺失时安全降级）
//    2) 创建「监视型(Monitor)」事件系统客户端，注册事件回调并挂到主 RunLoop。
//       Monitor 客户端会收到全系统 HID 事件的只读副本——包括其他 App 前台时
//       的键盘事件，因此退到后台依然能响应快捷键
//    3) 回调里自行跟踪修饰键按下/抬起状态，匹配用户配置的组合键，
//       命中则按步进调整系统音量并广播通知（供悬浮条/HUD 刷新）
//
//  边界与取舍：
//    - 只观测、不消费（Monitor 客户端无法也无需拦截事件），
//      因此同一组合键在原 App 里的自带功能不受影响（如 Safari ⌘++ 放大页面）
//    - App 处于前台时跳过处理，由 UIKeyCommand 响应，避免一次按键触发两次
//    - 修饰键状态在 start 时清零；若用户在 App 启动前一直按着修饰键，
//      下一次完整的按下-抬起循环后自愈
//

#import "KeyboardShortcutController.h"
#import "EVSettings.h"
#import "VolumeController.h"
#import "Private/IOHIDPrivate.h"
#import <dlfcn.h>
#import <UIKit/UIKit.h>

NSString *const kEVKeyboardVolumeAdjustedNotification = @"EVKeyboardVolumeAdjustedNotification";
NSString *const kEVKeyboardLogChangedNotification     = @"EVKeyboardLogChangedNotification";

// 内部修饰键状态位（非 HID usage，自用）
#define EVModCmd     (1u << 0)
#define EVModOption  (1u << 1)
#define EVModControl (1u << 2)
#define EVModShift   (1u << 3)

static void EVHIDEventCallback(void *target, void *refcon, void *queue, EVIOHIDEventRef event) {
    @autoreleasepool {
        [[KeyboardShortcutController shared] handleHIDEvent:event];
    }
}

@interface KeyboardShortcutController ()
@property (nonatomic, assign) BOOL hidAvailable;
@property (nonatomic, copy) NSString *clientTypeDesc;
@property (nonatomic, strong) NSMutableArray<NSString *> *logStore;
@property (nonatomic, strong) NSArray<NSString *> *eventLog;
@property (nonatomic, assign) uint32_t modifierBits;
@property (nonatomic, assign) BOOL started;
@property (nonatomic, assign) EVIOHIDEventSystemClientRef hidClient;
@property (nonatomic, strong) NSDateFormatter *logFormatter;

// 运行时解析的 IOHID 函数指针
@property (nonatomic, assign) EVHIDCreateWithTypeFn fnCreateWithType;
@property (nonatomic, assign) EVHIDCreateFn fnCreate;
@property (nonatomic, assign) EVHIDRegisterEventCallbackFn fnRegister;
@property (nonatomic, assign) EVHIDScheduleWithRunLoopFn fnSchedule;
@property (nonatomic, assign) EVHIDUnscheduleWithRunLoopFn fnUnschedule;
@property (nonatomic, assign) EVHIDEventGetTypeFn fnGetType;
@property (nonatomic, assign) EVHIDEventGetIntegerValueFn fnGetInt;

- (void)handleHIDEvent:(EVIOHIDEventRef)event;
- (void)applyStep:(float)sign logSuffix:(NSString *)suffix;
- (BOOL)resolveSymbols;
- (BOOL)createClient;
- (uint32_t)hidUsageForKey:(EVKBKey)key;
- (NSString *)keyInputForKBKey:(EVKBKey)key;
- (UIKeyModifierFlags)uiModifierFlagsForModifier:(EVKBModifier)modifier;
- (uint32_t)requiredBitsForModifier:(EVKBModifier)modifier;
- (BOOL)currentModifiersMatch:(EVKBModifier)modifier;
- (uint32_t)modifierBitForUsage:(uint32_t)usage;
- (NSString *)modifierGlyphForUsage:(uint32_t)usage;
- (void)logEvent:(NSString *)event;
@end

@implementation KeyboardShortcutController

+ (instancetype)shared {
    static KeyboardShortcutController *c;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ c = [KeyboardShortcutController new]; });
    return c;
}

#pragma mark - 生命周期

- (void)start {
    if (self.started) return;
    self.started = YES;
    self.modifierBits = 0;

    if (![self resolveSymbols]) {
        self.hidAvailable = NO;
        self.clientTypeDesc = @"IOKit 符号缺失";
        [self logEvent:@"IOHID 接口不可用：符号解析失败"];
        return;
    }
    if (![self createClient]) {
        self.hidAvailable = NO;
        [self logEvent:@"IOHID 客户端创建失败（后台监听不可用，前台快捷键仍有效）"];
        return;
    }
    self.hidAvailable = YES;
    [self logEvent:[NSString stringWithFormat:@"IOHID 后台监听已开启（%@）", self.clientTypeDesc]];
}

- (void)stop {
    if (!self.started) return;
    self.started = NO;
    if (self.hidClient && self.fnUnschedule) {
        self.fnUnschedule(self.hidClient, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    }
    if (self.hidClient && self.fnRegister) {
        self.fnRegister(self.hidClient, NULL, NULL, NULL);
    }
    self.hidClient = NULL;
    self.modifierBits = 0;
    self.hidAvailable = NO;
    [self logEvent:@"IOHID 后台监听已停止"];
}

- (void)clearLog {
    self.logStore = [NSMutableArray array];
    self.eventLog = @[];
}

#pragma mark - 私有接口初始化

- (BOOL)resolveSymbols {
    void *handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW);
    if (!handle) return NO;

    self.fnCreateWithType = (EVHIDCreateWithTypeFn)dlsym(handle, EVHID_SYM_CREATE_WITH_TYPE);
    self.fnCreate         = (EVHIDCreateFn)dlsym(handle, EVHID_SYM_CREATE);
    self.fnRegister       = (EVHIDRegisterEventCallbackFn)dlsym(handle, EVHID_SYM_REGISTER_CALLBACK);
    self.fnSchedule       = (EVHIDScheduleWithRunLoopFn)dlsym(handle, EVHID_SYM_SCHEDULE);
    self.fnUnschedule     = (EVHIDUnscheduleWithRunLoopFn)dlsym(handle, EVHID_SYM_UNSCHEDULE);
    self.fnGetType        = (EVHIDEventGetTypeFn)dlsym(handle, EVHID_SYM_EVENT_GET_TYPE);
    self.fnGetInt         = (EVHIDEventGetIntegerValueFn)dlsym(handle, EVHID_SYM_EVENT_GET_INT);

    // 必需符号缺一不可；Create 系列至少要有一种
    if (!self.fnRegister || !self.fnSchedule || !self.fnGetType || !self.fnGetInt) return NO;
    if (!self.fnCreateWithType && !self.fnCreate) return NO;
    return YES;
}

- (BOOL)createClient {
    EVIOHIDEventSystemClientRef client = NULL;

    // 优先 Monitor（收到全系统 HID 事件副本）；失败退到 Admin；再退到旧接口
    if (self.fnCreateWithType) {
        client = self.fnCreateWithType(kCFAllocatorDefault, EVHIDClientTypeMonitor, NULL);
        if (client) {
            self.clientTypeDesc = @"Monitor";
        } else {
            client = self.fnCreateWithType(kCFAllocatorDefault, EVHIDClientTypeAdmin, NULL);
            if (client) self.clientTypeDesc = @"Admin";
        }
    }
    if (!client && self.fnCreate) {
        client = self.fnCreate(kCFAllocatorDefault);
        if (client) self.clientTypeDesc = @"Legacy";
    }
    if (!client) {
        self.clientTypeDesc = @"创建失败";
        return NO;
    }

    self.fnRegister(client, EVHIDEventCallback, NULL, NULL);
    self.fnSchedule(client, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    self.hidClient = client;
    return YES;
}

#pragma mark - 事件处理

- (void)handleHIDEvent:(EVIOHIDEventRef)event {
    if (!event || !self.started || !self.hidClient) return;
    if (!self.fnGetType || !self.fnGetInt) return;
    if (self.fnGetType(event) != EVHIDEventTypeKeyboard) return;

    uint32_t page  = (uint32_t)self.fnGetInt(event, EVHIDFieldKeyboardUsagePage);
    uint32_t usage = (uint32_t)self.fnGetInt(event, EVHIDFieldKeyboardUsage);
    int down       = self.fnGetInt(event, EVHIDFieldKeyboardDown);
    int repeat     = self.fnGetInt(event, EVHIDFieldKeyboardRepeat);

    EVSettings *s = [EVSettings shared];

    // 厂商自定义页：地球键等特殊按键若产生硬件事件会出现在这里（诊断价值高，始终记录）
    if (page != 0x07) {
        if (down) {
            [self logEvent:[NSString stringWithFormat:@"捕获 页:0x%02X 键:0x%02X", page, usage]];
        }
        return;
    }

    // 修饰键状态跟踪（Left/Right Ctrl/Shift/Alt/GUI = 0xE0~0xE7）
    if (usage >= 0xE0 && usage <= 0xE7) {
        uint32_t bit = [self modifierBitForUsage:usage];
        if (down) {
            self.modifierBits |= bit;
            [self logEvent:[NSString stringWithFormat:@"%@ 按下", [self modifierGlyphForUsage:usage]]];
        } else {
            self.modifierBits &= ~bit;
        }
        return;
    }

    if (s.kbDiagnostic) {
        [self logEvent:[NSString stringWithFormat:@"诊断 键:0x%02X %@ 修饰:0x%02X",
                        usage, down ? @"按下" : @"抬起", (unsigned)self.modifierBits]];
    }
    if (!down || repeat) return;

    // App 前台时由 UIKeyCommand 处理，避免一次按键触发两次
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) return;
    if (!s.kbEnabled) return;

    float step = (float)s.kbStep;
    if (usage == [self hidUsageForKey:s.kbUpKey] && [self currentModifiersMatch:s.kbUpModifier]) {
        [self applyStep:+step logSuffix:@"增大"];
    } else if (usage == [self hidUsageForKey:s.kbDownKey] && [self currentModifiersMatch:s.kbDownModifier]) {
        [self applyStep:-step logSuffix:@"减小"];
    }
}

#pragma mark - 音量调整（两条触发路径共用）

- (void)applyStep:(float)sign {
    [self applyStep:sign logSuffix:nil];
}

- (void)applyStep:(float)sign logSuffix:(NSString *)suffix {
    float current = [VolumeController shared].volume;
    if (current < 0.0f) current = 0.0f;
    float target = fmaxf(0.0f, fminf(1.0f, current + sign));
    [[VolumeController shared] applyVolume:target];
    if (suffix) {
        [self logEvent:[NSString stringWithFormat:@"快捷键%@ → %d%%", suffix, (int)lroundf(target * 100.0f)]];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kEVKeyboardVolumeAdjustedNotification
                                                        object:nil
                                                      userInfo:@{@"volume": @(target)}];
}

#pragma mark - 前台 UIKeyCommand

- (NSArray<UIKeyCommand *> *)foregroundKeyCommands {
    EVSettings *s = [EVSettings shared];
    if (!s.kbEnabled) return nil;
    UIKeyCommand *up = [UIKeyCommand keyCommandWithInput:[self keyInputForKBKey:s.kbUpKey]
                                           modifierFlags:[self uiModifierFlagsForModifier:s.kbUpModifier]
                                                  action:@selector(evKBVolumeUp:)];
    UIKeyCommand *down = [UIKeyCommand keyCommandWithInput:[self keyInputForKBKey:s.kbDownKey]
                                             modifierFlags:[self uiModifierFlagsForModifier:s.kbDownModifier]
                                                    action:@selector(evKBVolumeDown:)];
    return @[up, down];
}

#pragma mark - 工具

- (uint32_t)hidUsageForKey:(EVKBKey)key {
    switch (key) {
        case EVKBKeyPlus:      return 0x2E;  // '=' 键（+ 是它的上档字符）
        case EVKBKeyMinus:     return 0x2D;
        case EVKBKeyUpArrow:   return 0x52;
        case EVKBKeyDownArrow: return 0x51;
    }
    return 0;
}

- (NSString *)keyInputForKBKey:(EVKBKey)key {
    switch (key) {
        case EVKBKeyPlus:      return @"+";
        case EVKBKeyMinus:     return @"-";
        case EVKBKeyUpArrow:   return UIKeyInputUpArrow;
        case EVKBKeyDownArrow: return UIKeyInputDownArrow;
    }
    return @"";
}

- (UIKeyModifierFlags)uiModifierFlagsForModifier:(EVKBModifier)modifier {
    switch (modifier) {
        case EVKBModifierCommand: return UIKeyModifierCommand;
        case EVKBModifierOption:  return UIKeyModifierAlternate;
        case EVKBModifierControl: return UIKeyModifierControl;
        case EVKBModifierShift:   return UIKeyModifierShift;
        case EVKBModifierNone:    return 0;
    }
    return 0;
}

- (uint32_t)requiredBitsForModifier:(EVKBModifier)modifier {
    switch (modifier) {
        case EVKBModifierCommand: return EVModCmd;
        case EVKBModifierOption:  return EVModOption;
        case EVKBModifierControl: return EVModControl;
        case EVKBModifierShift:   return EVModShift;
        case EVKBModifierNone:    return 0;
    }
    return 0;
}

/// 匹配时忽略 Shift——因为 "+" 字符本身就要 Shift+=，不能要求修饰键恰好只有一个 Shift
- (BOOL)currentModifiersMatch:(EVKBModifier)modifier {
    uint32_t required = [self requiredBitsForModifier:modifier];
    if (required == EVModShift) {
        return self.modifierBits == EVModShift;
    }
    return (self.modifierBits & ~EVModShift) == required;
}

- (uint32_t)modifierBitForUsage:(uint32_t)usage {
    switch (usage) {
        case 0xE0: case 0xE4: return EVModControl;
        case 0xE1: case 0xE5: return EVModShift;
        case 0xE2: case 0xE6: return EVModOption;
        case 0xE3: case 0xE7: return EVModCmd;
    }
    return 0;
}

- (NSString *)modifierGlyphForUsage:(uint32_t)usage {
    switch (usage) {
        case 0xE0: case 0xE4: return @"⌃";
        case 0xE1: case 0xE5: return @"⇧";
        case 0xE2: case 0xE6: return @"⌥";
        case 0xE3: case 0xE7: return @"⌘";
    }
    return @"?";
}

#pragma mark - 日志

- (void)logEvent:(NSString *)event {
    if (!self.logStore) self.logStore = [NSMutableArray array];
    if (!self.logFormatter) {
        self.logFormatter = [[NSDateFormatter alloc] init];
        self.logFormatter.dateFormat = @"HH:mm:ss";
    }
    [self.logStore addObject:[NSString stringWithFormat:@"%@ %@",
                              [self.logFormatter stringFromDate:[NSDate date]], event]];
    while (self.logStore.count > 40) {
        [self.logStore removeObjectAtIndex:0];
    }
    self.eventLog = [self.logStore copy];
    [[NSNotificationCenter defaultCenter] postNotificationName:kEVKeyboardLogChangedNotification object:nil];
}

#pragma mark - 显示名

+ (NSString *)displayNameForModifier:(EVKBModifier)modifier {
    switch (modifier) {
        case EVKBModifierNone:    return @"无修饰";
        case EVKBModifierCommand: return @"⌘";
        case EVKBModifierOption:  return @"⌥";
        case EVKBModifierControl: return @"⌃";
        case EVKBModifierShift:   return @"⇧";
    }
    return @"?";
}

+ (NSString *)displayNameForKey:(EVKBKey)key {
    switch (key) {
        case EVKBKeyPlus:      return @"+";
        case EVKBKeyMinus:     return @"-";
        case EVKBKeyUpArrow:   return @"↑";
        case EVKBKeyDownArrow: return @"↓";
    }
    return @"?";
}

@end

// ============================================================
// 前台快捷键动作
// UIKeyCommand 以 nil target 创建，UIKit 会沿响应链查找实现了
// 这两个选择器的对象。挂在 UIResponder 上，保证链路上任意
// 响应者（设置页/悬浮层）都能接住。
// ============================================================
@implementation UIResponder (EVKeyboardShortcutActions)

- (void)evKBVolumeUp:(UIKeyCommand *)sender {
    [[KeyboardShortcutController shared] applyStep:+(float)[EVSettings shared].kbStep];
}

- (void)evKBVolumeDown:(UIKeyCommand *)sender {
    [[KeyboardShortcutController shared] applyStep:-(float)[EVSettings shared].kbStep];
}

@end
