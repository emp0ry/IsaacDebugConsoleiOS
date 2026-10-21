#import "IDCHotkey.h"
#import "IDCLogger.h"

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// AppKit is present in the PlayCover/Catalyst host, but must not become a
// linked dependency of the iPhone build. These are public NSEvent methods.
@protocol IDCDesktopKeyEvent <NSObject>
@property(nonatomic, readonly) unsigned short keyCode;
@property(nonatomic, readonly) NSUInteger modifierFlags;
@property(nonatomic, readonly) NSInteger type;
@property(nonatomic, readonly) BOOL isARepeat;
@end

@protocol IDCDesktopEventMonitoring <NSObject>
+ (nullable id)addLocalMonitorForEventsMatchingMask:(NSUInteger)mask
                                           handler:(id _Nullable (^)(id event))handler;
+ (void)removeMonitor:(id)monitor;
@end

@interface IDCHotkey ()
@property(nonatomic, copy) BOOL (^handler)(void);
@property(nonatomic, strong, nullable) id desktopMonitor;
@property(nonatomic) BOOL keyHeld;
- (BOOL)handleEvent:(UIEvent *)event;
@end

static __weak IDCHotkey *gHotkey;
static void (*gOriginalSendEvent)(id, SEL, UIEvent *);

static void IDCSendEvent(id application, SEL selector, UIEvent *event) {
    if ([gHotkey handleEvent:event]) return;
    gOriginalSendEvent(application, selector, event);
}

@implementation IDCHotkey

- (instancetype)initWithHandler:(BOOL (^)(void))handler {
    self = [super init];
    if (self) _handler = [handler copy];
    return self;
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
    Class<IDCDesktopEventMonitoring> events = (Class)NSClassFromString(@"NSEvent");
    if (_desktopMonitor && [events respondsToSelector:@selector(removeMonitor:)]) {
        [events removeMonitor:_desktopMonitor];
    }
}

- (void)resetHeldKey:(NSNotification *)notification {
    (void)notification;
    self.keyHeld = NO;
}

- (BOOL)keyDown:(BOOL)down repeat:(BOOL)repeat {
    if (!down) {
        BOOL handled = self.keyHeld;
        self.keyHeld = NO;
        return handled;
    }
    if (self.keyHeld) return YES;
    if (repeat || UIApplication.sharedApplication.applicationState != UIApplicationStateActive) {
        return NO;
    }
    BOOL handled = self.handler ? self.handler() : NO;
    self.keyHeld = handled;
    return handled;
}

- (BOOL)handleEvent:(UIEvent *)event {
    if (event.type != UIEventTypePresses || ![event isKindOfClass:UIPressesEvent.class]) return NO;
    NSSet<UIPress *> *presses = ((UIPressesEvent *)event).allPresses;
    if (!presses.count) return NO;
    BOOL allHandled = YES;
    for (UIPress *press in presses) {
        UIKey *key = press.key;
        UIKeyModifierFlags modifiers = UIKeyModifierShift | UIKeyModifierControl |
            UIKeyModifierAlternate | UIKeyModifierCommand;
        BOOL grave = key && key.keyCode == UIKeyboardHIDUsageKeyboardGraveAccentAndTilde;
        BOOL released = press.phase == UIPressPhaseEnded || press.phase == UIPressPhaseCancelled;
        if (!grave || (!released && (key.modifierFlags & modifiers))) {
            allHandled = NO;
            continue;
        }
        BOOL handled = NO;
        if (press.phase == UIPressPhaseBegan) handled = [self keyDown:YES repeat:NO];
        else if (released) handled = [self keyDown:NO repeat:NO];
        else handled = self.keyHeld;
        if (!handled) allHandled = NO;
    }
    // Never suppress unrelated keys, touches, controller events, or lifecycle events.
    return allHandled;
}

- (void)start {
    NSAssert(NSThread.isMainThread, @"Install the console shortcut on the main thread");
    gHotkey = self;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Class application = object_getClass(UIApplication.sharedApplication);
        SEL selector = @selector(sendEvent:);
        Method method = class_getInstanceMethod(application, selector);
        if (!method) return;
        gOriginalSendEvent = (void (*)(id, SEL, UIEvent *))method_getImplementation(method);
        if (!class_addMethod(application, selector, (IMP)IDCSendEvent,
                             method_getTypeEncoding(method))) {
            method_setImplementation(method, (IMP)IDCSendEvent);
        }
    });
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(resetHeldKey:)
        name:UIApplicationWillResignActiveNotification object:nil];

    Class<IDCDesktopEventMonitoring> events = (Class)NSClassFromString(@"NSEvent");
    if (!self.desktopMonitor && NSClassFromString(@"NSApplication") != Nil &&
        [events respondsToSelector:@selector(addLocalMonitorForEventsMatchingMask:handler:)]) {
        __weak IDCHotkey *weakSelf = self;
        // NSEventMaskKeyDown | NSEventMaskKeyUp. Use the physical grave key so
        // switching the macOS keyboard layout does not move the shortcut.
        self.desktopMonitor = [events addLocalMonitorForEventsMatchingMask:(1UL << 10) | (1UL << 11)
            handler:^id(id<IDCDesktopKeyEvent> event) {
                IDCHotkey *strongSelf = weakSelf;
                if (!strongSelf || event.keyCode != 50) return event;
                BOOL released = event.type == 11;
                NSUInteger modifiers = (1UL << 17) | (1UL << 18) | (1UL << 19) | (1UL << 20);
                if (!released && (event.modifierFlags & modifiers)) return event;
                return [strongSelf keyDown:!released repeat:event.isARepeat] ? nil : event;
            }];
    }
    IDCLog(@"grave-key shortcut installed (%@)",
           self.desktopMonitor ? @"UIKit + Catalyst" : @"UIKit hardware keyboard");
}
@end
