//
//  KeyboardShortcutController.h
//  EdgeVolume
//
//  硬件键盘快捷键调音量（秒空键盘没有音量键的替代方案）。
//
//  两条触发路径：
//   1) 后台/其他 App 前台时：IOHID 私有接口监视全系统键盘事件（本类实现）。
//      只观测不消费，不影响按键在原 App 里的正常功能。
//   2) 本 App 前台时：UIKit 的 UIKeyCommand（见 SettingsViewController /
//      OverlayRootViewController 的 keyCommands），避免与本类重复触发。
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "EVSettings.h"

/// 快捷键触发后广播（userInfo: @{@"volume": @(float)}）
extern NSString *const kEVKeyboardVolumeAdjustedNotification;
/// 诊断日志更新时广播（设置页刷新「最近捕获」用）
extern NSString *const kEVKeyboardLogChangedNotification;

@class UIKeyCommand;

@interface KeyboardShortcutController : NSObject

+ (instancetype)shared;

/// IOHID 私有接口是否可用（dlopen 且客户端创建成功）
@property (nonatomic, assign, readonly) BOOL hidAvailable;
/// 客户端类型描述（诊断信息，如 "Monitor"/"Admin"/"Legacy"）
@property (nonatomic, copy, readonly) NSString *clientTypeDesc;
/// 最近捕获的按键事件（诊断日志，倒序显示由 UI 决定）
@property (nonatomic, strong, readonly) NSArray<NSString *> *eventLog;

/// 开启后台键盘监听（AppDelegate 启动时调用；内部按设置决定是否处理事件）
- (void)start;
/// 停止监听
- (void)stop;
/// 清空诊断日志
- (void)clearLog;

/// 按步进调整音量并广播（两条触发路径共用；sign 传 +1/-1 或步进浮点数）
- (void)applyStep:(float)sign;

/// 构成本 App 前台的 UIKeyCommand 列表（target 为 nil，动作走响应链；
/// 未启用快捷键时返回 nil）
- (NSArray<UIKeyCommand *> *)foregroundKeyCommands;

/// 显示名：修饰键
+ (NSString *)displayNameForModifier:(EVKBModifier)modifier;
/// 显示名：主键
+ (NSString *)displayNameForKey:(EVKBKey)key;

@end

/// 前台快捷键动作：UIKeyCommand 以 nil target 创建，UIKit 沿响应链查找
/// 实现了这两个选择器的响应者（设置页 / 悬浮层均可接住）
@interface UIResponder (EVKeyboardShortcutActions)
- (void)evKBVolumeUp:(UIKeyCommand *)sender;
- (void)evKBVolumeDown:(UIKeyCommand *)sender;
@end
