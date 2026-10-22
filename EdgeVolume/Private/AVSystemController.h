//  Celestial 私有框架中的 AVSystemController 声明
//  UIKit 已引用 Celestial，运行时通过 NSClassFromString 即可取到该类，无需链接私有框架
//  仅巨魔（TrollStore）安装可用；App Store 上架会因私有 API 被拒
#import <Foundation/Foundation.h>

@interface AVSystemController : NSObject

+ (instancetype)sharedAVSystemController;

/// 直接设置某个类别的系统音量（不会弹出系统音量 HUD）
/// category 常用值：@"Audio/Video"（媒体音量）、@"Ringtone"（铃音量）、@"UserInterfaceSoundEffects"
- (BOOL)setVolumeTo:(float)volume forCategory:(NSString *)category;

@end
