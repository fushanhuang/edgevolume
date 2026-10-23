//
//  IOHIDPrivate.h
//  EdgeVolume
//
//  IOHID 私有接口的最小声明集（dlopen 运行时解析，不链接 IOKit.framework）。
//  常量值来自 Apple IOHIDFamily 头文件（经 theos/headers、ravynos 仓库核对）：
//    - IOHIDEventTypes.h:      kIOHIDEventTypeKeyboard = 3
//    - IOHIDEventTypes.h:      IOHIDEventFieldBase(type) = (type << 16)
//    - IOHIDEventSystemClientPrivate.h: Admin=0 Monitor=1 Filter=2 Passive=3
//  HID usage 表（USB HID Usage Tables）：
//    - Keyboard/Keypad Page = 0x07；'=' 键=0x2E，'-' 键=0x2D，↑=0x52，↓=0x51
//    - 修饰键：LeftCtrl=0xE0 LeftShift=0xE1 LeftAlt=0xE2 LeftGUI=0xE3
//              RightCtrl=0xE4 RightShift=0xE5 RightAlt=0xE6 RightGUI=0xE7
//

#import <Foundation/Foundation.h>

#ifndef EV_IOHID_PRIVATE_H
#define EV_IOHID_PRIVATE_H

// ---- 事件类型 ----
#define EVHIDEventTypeKeyboard 3u

// ---- 键盘事件字段（IOHIDEventFieldBase(3) = 3<<16）----
#define EVHIDFieldKeyboardUsagePage  (3u << 16)        // 0x00030000
#define EVHIDFieldKeyboardUsage      ((3u << 16) + 1u) // 0x00030001
#define EVHIDFieldKeyboardDown       ((3u << 16) + 2u) // 0x00030002
#define EVHIDFieldKeyboardRepeat     ((3u << 16) + 3u) // 0x00030003

// ---- 事件系统客户端类型 ----
#define EVHIDClientTypeAdmin   0u
#define EVHIDClientTypeMonitor 1u   // 监视型：收到全系统 HID 事件副本（只读）

// ---- 不透明类型（只用指针）----
typedef const struct __EVIOHIDEvent *EVIOHIDEventRef;
typedef struct __EVIOHIDEventSystemClient *EVIOHIDEventSystemClientRef;

// 回调签名对照 IOHIDEventSystemClientEventCallback：
// void (*)(void* target, void* refcon, IOHIDEventQueueRef queue, IOHIDEventRef event)
typedef void (*EVHIDEventCallback)(void *target, void *refcon, void *queue, EVIOHIDEventRef event);

// ---- 运行时解析的函数指针类型 ----
typedef EVIOHIDEventSystemClientRef (*EVHIDCreateWithTypeFn)(CFAllocatorRef allocator,
                                                             uint32_t clientType,
                                                             void *data);
typedef EVIOHIDEventSystemClientRef (*EVHIDCreateFn)(CFAllocatorRef allocator);
typedef void (*EVHIDRegisterEventCallbackFn)(EVIOHIDEventSystemClientRef client,
                                             EVHIDEventCallback callback,
                                             void *target, void *refcon);
typedef void (*EVHIDScheduleWithRunLoopFn)(EVIOHIDEventSystemClientRef client,
                                           CFRunLoopRef runLoop, CFStringRef mode);
typedef void (*EVHIDUnscheduleWithRunLoopFn)(EVIOHIDEventSystemClientRef client,
                                             CFRunLoopRef runLoop, CFStringRef mode);
typedef uint32_t (*EVHIDEventGetTypeFn)(EVIOHIDEventRef event);
typedef int (*EVHIDEventGetIntegerValueFn)(EVIOHIDEventRef event, uint32_t field);

// IOKit 里的符号名（dlsym 用）
#define EVHID_SYM_CREATE_WITH_TYPE  "IOHIDEventSystemClientCreateWithType"
#define EVHID_SYM_CREATE            "IOHIDEventSystemClient"
#define EVHID_SYM_REGISTER_CALLBACK "IOHIDEventSystemClientRegisterEventCallback"
#define EVHID_SYM_SCHEDULE          "IOHIDEventSystemClientScheduleWithRunLoop"
#define EVHID_SYM_UNSCHEDULE        "IOHIDEventSystemClientUnscheduleWithRunLoop"
#define EVHID_SYM_EVENT_GET_TYPE    "IOHIDEventGetType"
#define EVHID_SYM_EVENT_GET_INT     "IOHIDEventGetIntegerValue"

#endif /* EV_IOHID_PRIVATE_H */
