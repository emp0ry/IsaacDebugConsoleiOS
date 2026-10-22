#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "IDCHotkey.h"
#include <assert.h>

NSString *const UIApplicationWillResignActiveNotification=@"CheckSuspend";
@implementation UIKey @end
@implementation UIPress @end
@implementation UIEvent @end
@implementation UIPressesEvent @end
@implementation UIApplication
+ (UIApplication *)sharedApplication { static UIApplication *app; if (!app) app=[UIApplication new]; return app; }
- (void)sendEvent:(UIEvent *)event { (void)event; self.forwarded++; }
@end
void IDCLog(NSString *format,...) { (void)format; }
static NSMutableArray *Monitors;
@interface NSApplication : NSObject @end
@implementation NSApplication @end
@interface NSEvent : NSObject
@property(nonatomic) unsigned short keyCode;
@property(nonatomic) NSUInteger modifierFlags;
@property(nonatomic) NSInteger type;
@property(nonatomic) BOOL isARepeat;
@end
@implementation NSEvent
+ (id)addLocalMonitorForEventsMatchingMask:(NSUInteger)mask handler:(id (^)(id))handler {
    assert(mask&(1UL<<10)); if (!Monitors) Monitors=[NSMutableArray new];
    [Monitors addObject:[handler copy]]; return handler;
}
+ (void)removeMonitor:(id)monitor { [Monitors removeObject:monitor]; }
@end
static BOOL Open;
static int Opens,Closes,NativePauses;
static BOOL Close(void) { if (!Open) return NO; Open=NO; Closes++; return YES; }
static BOOL FixHeld,FixConsumed;
static BOOL FixEscape(BOOL down,BOOL repeat,BOOL modified) {
    if (!down) { BOOL handled=FixConsumed; FixHeld=NO; FixConsumed=NO; return handled; }
    if (FixHeld) return FixConsumed;
    FixHeld=YES;
    if (repeat || modified) return NO;
    NSMutableDictionary *request=[NSMutableDictionary dictionary];
    [NSNotificationCenter.defaultCenter postNotificationName:@"com.emp0ry.isaacconsole.closeForEscape" object:request];
    if (![request[@"handled"] boolValue]) NativePauses++;
    FixConsumed=YES; return YES;
}
static void (*FixOriginal)(id,SEL,UIEvent *);
static void FixSendEvent(id app,SEL selector,UIEvent *event) {
    if ([event isKindOfClass:UIPressesEvent.class]) {
        UIPress *p=((UIPressesEvent *)event).allPresses.anyObject;
        if (p.key.keyCode==0x29 && (p.phase==UIPressPhaseBegan || p.phase==UIPressPhaseEnded))
            if (FixEscape(p.phase==UIPressPhaseBegan,NO,p.key.modifierFlags!=0)) return;
    }
    FixOriginal(app,selector,event);
}
static void InstallFixes(void) {
    Method method=class_getInstanceMethod(UIApplication.class,@selector(sendEvent:));
    FixOriginal=(void (*)(id,SEL,UIEvent *))method_setImplementation(method,(IMP)FixSendEvent);
    [NSEvent addLocalMonitorForEventsMatchingMask:(1UL<<10)|(1UL<<11) handler:^id(NSEvent *e) {
        if (e.keyCode!=53) return e;
        return FixEscape(e.type!=11,e.isARepeat,e.modifierFlags!=0)?nil:e;
    }];
}
static void UIKitKey(int code,UIPressPhase phase,UIKeyModifierFlags flags) {
    UIKey *key=[UIKey new]; key.keyCode=code; key.modifierFlags=flags;
    UIPress *p=[UIPress new]; p.key=key; p.phase=phase;
    UIPressesEvent *e=[UIPressesEvent new]; e.type=UIEventTypePresses; e.allPresses=[NSSet setWithObject:p];
    [UIApplication.sharedApplication sendEvent:e];
}
static void MacKey(int code,int type,BOOL repeat,NSUInteger flags) {
    NSEvent *e=[NSEvent new]; e.keyCode=code; e.type=type; e.isARepeat=repeat; e.modifierFlags=flags;
    id current=e; for (id (^handler)(id) in Monitors) { if (!current) break; current=handler(current); }
}
int main(int argc,char **argv) {
    (void)argv;
    @autoreleasepool {
        id observer=[NSNotificationCenter.defaultCenter addObserverForName:@"com.emp0ry.isaacconsole.closeForEscape"
            object:nil queue:nil usingBlock:^(NSNotification *n) { if (Close()) ((NSMutableDictionary *)n.object)[@"handled"]=@YES; }];
        IDCHotkey *keys=[[IDCHotkey alloc] initWithHandler:^BOOL { if (!Close()) { Open=YES; Opens++; } return YES; }
            closeHandler:^BOOL { return Close(); }];
        if (argc>1) { [keys start]; InstallFixes(); } else { InstallFixes(); [keys start]; }
        UIKitKey(0x35,UIPressPhaseBegan,0); UIKitKey(0x35,UIPressPhaseEnded,0); assert(Open && Opens==1);
        UIKitKey(0x29,UIPressPhaseBegan,0); UIKitKey(0x29,UIPressPhaseBegan,0); UIKitKey(0x29,UIPressPhaseEnded,0);
        assert(!Open && Closes==1 && NativePauses==0);
        UIKitKey(0x29,UIPressPhaseBegan,0); UIKitKey(0x29,UIPressPhaseEnded,0); assert(NativePauses==1);
        MacKey(50,10,NO,0); MacKey(50,11,NO,0); assert(Open && Opens==2);
        MacKey(53,10,NO,0); MacKey(53,10,YES,0); MacKey(53,11,NO,0);
        assert(!Open && Closes==2 && NativePauses==1);
        MacKey(53,10,NO,0); MacKey(53,11,NO,0); assert(NativePauses==2);
        MacKey(50,10,NO,0); MacKey(50,11,NO,0);
        MacKey(50,10,NO,0); MacKey(50,10,YES,0); MacKey(50,11,NO,0);
        assert(!Open && Opens==3 && Closes==3);
        MacKey(53,10,NO,1UL<<20); MacKey(53,10,YES,0); MacKey(53,11,NO,0); assert(NativePauses==2);
        MacKey(50,10,NO,0); MacKey(50,11,NO,0); assert(Open);
        MacKey(53,10,NO,1UL<<20); MacKey(53,10,YES,0); MacKey(53,11,NO,0); assert(Open);
        UIKitKey(4,UIPressPhaseBegan,0); assert(UIApplication.sharedApplication.forwarded>0);
        [NSNotificationCenter.defaultCenter removeObserver:observer];
        puts("Console shortcuts passed: UIKit/Mac grave + Escape, repeats, modifiers, both Fixes monitor orders, no double pause");
    }
}
