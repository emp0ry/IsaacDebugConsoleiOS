#import "IDCCommandEngine.h"
#import "IDCConsoleController.h"
#import "IDCItemCatalog.h"
#import "IDCLogger.h"
#import "IDCNativeBridge.h"

#import <UIKit/UIKit.h>

static IDCConsoleController *gConsoleController;
static dispatch_once_t gStartOnce;

static void IDCStart(void) {
    dispatch_once(&gStartOnce, ^{
        IDCNativeBridge *bridge = [IDCNativeBridge new];
        NSString *bundleID = NSBundle.mainBundle.bundleIdentifier ?: @"";
        BOOL isaacBundle = [bundleID isEqualToString:@"com.Nicalis.Isaac-iOS"];
        if (!isaacBundle && !bridge.isSupportedBuild) return;
        IDCItemCatalog *catalog = [IDCItemCatalog new];
        IDCCommandEngine *engine = [[IDCCommandEngine alloc] initWithBridge:bridge
                                                                    catalog:catalog];
        gConsoleController = [[IDCConsoleController alloc] initWithBridge:bridge engine:engine];
        [gConsoleController start];
        IDCLog(@"started in %@%@", bundleID,
               isaacBundle ? @"" : @" (verified Isaac guest image)");
    });
}

__attribute__((constructor)) static void IDCConstructor(void) {
    @autoreleasepool {
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSNotificationCenter.defaultCenter
                addObserverForName:UIApplicationDidBecomeActiveNotification
                            object:nil queue:NSOperationQueue.mainQueue
                        usingBlock:^(__unused NSNotification *notification) { IDCStart(); }];
            if (UIApplication.sharedApplication.applicationState == UIApplicationStateActive) {
                IDCStart();
            }
        });
    }
}
