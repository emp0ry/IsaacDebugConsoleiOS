#import <Foundation/Foundation.h>
typedef NS_ENUM(NSInteger,UIEventType) { UIEventTypeTouches=0,UIEventTypePresses=4 };
typedef NS_ENUM(NSInteger,UIPressPhase) { UIPressPhaseBegan=0,UIPressPhaseChanged=1,UIPressPhaseStationary=2,UIPressPhaseEnded=3,UIPressPhaseCancelled=4 };
typedef NS_OPTIONS(NSUInteger,UIKeyModifierFlags) { UIKeyModifierShift=1<<17,UIKeyModifierControl=1<<18,UIKeyModifierAlternate=1<<19,UIKeyModifierCommand=1<<20 };
typedef NS_ENUM(NSInteger,UIApplicationState) { UIApplicationStateActive=0,UIApplicationStateInactive=1 };
enum { UIKeyboardHIDUsageKeyboardGraveAccentAndTilde=0x35,UIKeyboardHIDUsageKeyboardEscape=0x29 };
extern NSString *const UIApplicationWillResignActiveNotification;
@interface UIKey : NSObject
@property(nonatomic) NSInteger keyCode;
@property(nonatomic) UIKeyModifierFlags modifierFlags;
@end
@interface UIPress : NSObject
@property(nonatomic,strong) UIKey *key;
@property(nonatomic) UIPressPhase phase;
@end
@interface UIEvent : NSObject
@property(nonatomic) UIEventType type;
@end
@interface UIPressesEvent : UIEvent
@property(nonatomic,copy) NSSet<UIPress *> *allPresses;
@end
@interface UIApplication : NSObject
@property(class,readonly) UIApplication *sharedApplication;
@property(nonatomic) UIApplicationState applicationState;
@property(nonatomic) NSInteger forwarded;
- (void)sendEvent:(UIEvent *)event;
@end
