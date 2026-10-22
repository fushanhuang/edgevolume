#import <UIKit/UIKit.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "FBSOrientationObserver.h"
#import "FBSOrientationUpdate.h"
typedef struct {
	unsigned val[8];
} SCD_Struct_RB3;

@interface LSApplicationProxy : NSObject
@property(nonatomic, assign, readonly) NSString *bundleIdentifier;
@property(nonatomic, assign, readonly) NSString *localizedShortName;
@property(nonatomic, assign, readonly) NSString *primaryIconName;
@end

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (NSArray <LSApplicationProxy *> *)allInstalledApplications;
@end

@interface BSCornerRadiusConfiguration : NSObject
- (id)initWithTopLeft:(CGFloat)tl bottomLeft:(CGFloat)bl bottomRight:(CGFloat)br topRight:(CGFloat)tr;
@end

// BoardServices
@interface BSSettings : NSObject
@end

@interface BSTransaction : NSObject
- (void)addChildTransaction:(id)transaction;
- (void)begin;
- (void)setCompletionBlock:(dispatch_block_t)block;
@end

// FrontBoard

@class RBSProcessIdentity, FBProcessExecutableSlice, UIMutableApplicationSceneSettings, UIMutableApplicationSceneClientSettings, UIScenePresentationManager, _UIScenePresenter;

@interface FBApplicationProcessLaunchTransaction : BSTransaction
- (instancetype) initWithProcessIdentity:(RBSProcessIdentity *)identity executionContextProvider:(id)providerBlock;
- (void)_begin;
@end

@interface FBProcessExecutionContext : NSObject
@end

@interface FBMutableProcessExecutionContext : FBProcessExecutionContext

@property (nonatomic,copy) RBSProcessIdentity * identity; 
@property (nonatomic,copy) NSArray * arguments; 
@property (nonatomic,copy) NSDictionary * environment; 
@property (nonatomic,retain) NSURL * standardOutputURL; 
@property (nonatomic,retain) NSURL * standardErrorURL; 
@property (assign,nonatomic) BOOL waitForDebugger; 
@property (assign,nonatomic) BOOL disableASLR; 
@property (assign,nonatomic) BOOL checkForLeaks; 
@property (assign,nonatomic) long long launchIntent; 
//@property (nonatomic,retain) id<FBProcessWatchdogProviding> watchdogProvider; 
@property (nonatomic,copy) NSString * overrideExecutablePath; 
//@property (nonatomic,retain) FBProcessExecutableSlice * overrideExecutableSlice; 
@property (nonatomic,copy) id completion; 
-(id)copyWithZone:(NSZone*)arg1 ;
@end

@interface FBProcess : NSObject
- (id)name;
@end

@interface FBScene : NSObject
- (FBProcess *)clientProcess;
- (UIScenePresentationManager *)uiPresentationManager;
- (void)updateSettings:(UIMutableApplicationSceneSettings *)settings withTransitionContext:(id)context completion:(id)completion;
@property (nonatomic, readonly) UIMutableApplicationSceneSettings * settings;
@end

@interface FBDisplayManager : NSObject
+ (instancetype)sharedInstance;
- (id)mainConfiguration;
@end

@interface FBSSceneClientIdentity : NSObject
+ (instancetype)identityForBundleID:(NSString *)bundleID;
+ (instancetype)identityForProcessIdentity:(RBSProcessIdentity *)identity;
+ (instancetype)localIdentity;
@end

@interface FBProcessManager : NSObject
+ (instancetype)sharedInstance;
- (FBProcessExecutionContext *)launchProcessWithContext:(FBMutableProcessExecutionContext *)context;
- (void)registerProcessForAuditToken:(SCD_Struct_RB3)token;
@end

@interface FBSSceneSpecification : NSObject
+ (instancetype)specification;
@end

// RunningBoardServices
@interface RBSProcessIdentity : NSObject
+ (instancetype)identityForEmbeddedApplicationIdentifier:(NSString *)identifier;
+ (id)identityForExecutablePath:(NSString *)arg1 pid:(int)arg2 auid:(unsigned int)arg3;
@end

@interface RBSProcessPredicate
+ (instancetype)predicateMatchingIdentity:(RBSProcessIdentity *)identity;
@end

@interface RBSProcessHandle
+ (instancetype)handleForPredicate:(RBSProcessPredicate *)predicate error:(NSError **)error;
- (SCD_Struct_RB3)auditToken;
@end

@interface UIApplicationSceneSpecification : FBSSceneSpecification
@end

@interface FBSSceneIdentity : NSObject
+ (instancetype)identityForIdentifier:(NSString *)id;
@end

// FBSSceneSettings
@interface UIMutableApplicationSceneSettings : NSObject
@property(nonatomic, assign, readwrite) BOOL canShowAlerts;
@property(nonatomic, assign) BOOL deviceOrientationEventsEnabled;
@property(nonatomic, assign, readwrite) NSInteger interruptionPolicy;
@property(nonatomic, strong, readwrite) NSString *persistenceIdentifier;
@property (nonatomic, assign, readwrite) UIEdgeInsets peripheryInsets;
@property (nonatomic, assign, readwrite) UIEdgeInsets safeAreaInsetsPortrait, safeAreaInsetsPortraitUpsideDown, safeAreaInsetsLandscapeLeft, safeAreaInsetsLandscapeRight;
@property (nonatomic, strong, readwrite) BSCornerRadiusConfiguration *cornerRadiusConfiguration;
- (id)displayConfiguration;
- (CGRect)frame;
- (NSMutableSet *)ignoreOcclusionReasons;
- (void)setDisplayConfiguration:(id)c;
- (void)setForeground:(BOOL)f;
- (void)setFrame:(CGRect)frame;
- (void)setLevel:(NSInteger)level;
- (void)setStatusBarDisabled:(BOOL)disabled;
- (void)setInterfaceOrientation:(NSInteger)o;
- (BSSettings *)otherSettings;
@end

@interface FBSSceneParameters : NSObject
@property(nonatomic, copy) UIMutableApplicationSceneSettings *settings;
@property(nonatomic, copy) UIMutableApplicationSceneClientSettings *clientSettings;
+ (instancetype)parametersForSpecification:(FBSSceneSpecification *)spec;
//- (void)updateSettingsWithBlock:(id)block;
@end

@interface FBSMutableSceneParameters : FBSSceneParameters
//- (void)updateClientSettingsWithBlock:(id)block;
@end

@interface FBSMutableSceneDefinition : NSObject
@property(nonatomic, copy) FBSSceneClientIdentity *clientIdentity;
@property(nonatomic, copy) FBSSceneIdentity *identity;
@property(nonatomic, copy) FBSSceneSpecification *specification;
+ (instancetype)definition;
@end

@interface FBSceneManager : NSObject
+ (instancetype)sharedInstance;
+ (instancetype)keyboardScene;
+ (void)setKeyboardScene:(id)arg1;
+ (id)observeKeyboardSceneAvailability:(id /* block */)arg1;
@property (nonatomic) id delegate;
- (FBScene *)createSceneWithDefinition:(id)def initialParameters:(id)params;
- (id)createSceneWithDefinition:(id)arg1;
@end

@interface UIImage(internal)
+ (instancetype)_applicationIconImageForBundleIdentifier:(NSString *)bundleID format:(NSInteger)format scale:(CGFloat)scale;
@end

// UIKit
@interface UIApplicationSceneTransitionContext : NSObject
@end

@interface UIMutableApplicationSceneClientSettings : NSObject
@property(nonatomic, assign) long long interfaceOrientation;
@property(nonatomic, assign) NSInteger statusBarStyle;
@end

@interface UIWindow()
- (instancetype)_initWithFrame:(CGRect)frame attached:(BOOL)attached;
- (void)orderFront:(id)arg1;
- (void)_adjustSizeClassesAndResizeWindowToFrame:(CGRect)arg1;
- (void)_rotateWindowToOrientation:(long long)arg1 updateStatusBar:(bool)arg2 duration:(double)arg3 skipCallbacks:(bool)arg4;
- (void)_rotateToBounds:(CGRect)arg1 withAnimator:(id)arg2 transitionContext:(id)arg3;
@end

@interface UIScreen()
- (CGRect)_referenceBounds;
- (id)displayConfiguration;
@end

@interface UIWindowScene()
- (CGRect)_referenceBounds;
- (CGRect)_referenceBoundsForOrientation:(long long)arg1;
- (void)_updateClientSettingsToInterfaceOrientation:(long long)arg1 withAnimationDuration:(double)arg2;
@property (nonatomic, readonly) id keyboardSceneDelegate;
@end

@interface UIScenePresentationBinder : NSObject
- (void)addScene:(id)scene;

@end

@interface UIScenePresentationManager : NSObject
- (instancetype)_initWithScene:(FBScene *)scene;
- (_UIScenePresenter *)createPresenterWithIdentifier:(NSString *)identifier;
@end

@interface _UIScenePresenterOwner : NSObject
- (instancetype)initWithScenePresentationManager:(UIScenePresentationManager *)manager context:(FBScene *)scene;
@end

@interface _UIScenePresentationView : UIView
//- (instancetype)initWithPresenter:(_UIScenePresenter *)presenter;
@end

@interface _UIScenePresenter : NSObject
@property (nonatomic, assign, readonly) _UIScenePresentationView *presentationView;
@property(nonatomic, assign, readonly) FBScene *scene;
- (instancetype)initWithOwner:(_UIScenePresenterOwner *)manager identifier:(NSString *)scene sortContext:(NSNumber *)context;
- (void)activate;
- (void)deactivate;
- (void)invalidate;
@end

@interface UIRootWindowScenePresentationBinder : UIScenePresentationBinder
- (instancetype)initWithPriority:(int)pro displayConfiguration:(id)c;
- (NSSet *)scenes;
@end

@interface UIScenePresentationContext : NSObject
- (UIScenePresentationContext *)_initWithDefaultValues;
@end

@interface _UISceneLayerHostContainerView : UIView
- (instancetype)initWithScene:(FBScene *)scene debugDescription:(NSString *)desc;
- (void)_setPresentationContext:(UIScenePresentationContext *)context;
@end

@interface UIApplication()
- (void)launchApplicationWithIdentifier:(NSString *)identifier suspended:(BOOL)suspended;
- (void)_requestSceneActivationWithConfiguration:(id)arg1 animated:(bool)arg2 sender:(id)arg3 errorHandler:(id)arg4;
- (void)_requestSceneSessionActivationWithConfiguration:(id)arg1 errorHandler:(id)arg2;
- (id)_connectUISceneFromFBSScene:(id)arg1 transitionContext:(id)arg2;
- (id)_infoPlistSceneConfigurations;
@end

@interface UIViewController()
- (CGRect)_boundsForOrientation:(long long)arg1;
@end


// PreviewsServicesUI
@interface UVInjectedScene: NSObject
@property(nonatomic, assign, readonly) FBScene *scene;
@property(nonatomic, assign, readonly) NSString *sceneIdentifier;
+ (instancetype)injectInProcess:(NSInteger)pid error:(NSError **)error;
+ (instancetype)_injectInProcessHandle:(RBSProcessHandle *)process error:(NSError **)error;
@end

@interface UVSceneHost : UIView
+ (instancetype)createWithInjectedScene:(UVInjectedScene *)scene error:(NSError **)error;
@end

///---------------------------------------



@interface UIKeyboardSceneDelegate : NSObject
+ (id)activeKeyboardSceneDelegate;
@property (nonatomic, readonly) id containerWindow;
-(id)forceCreateKeyboardWindow;
@end

