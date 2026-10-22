#import "IDCCommandEngine.h"
#import "IDCNativeBridge.h"
#import "IDCItemCatalog.h"
#include <assert.h>
void IDCLog(NSString *format, ...) { (void)format; }
@implementation IDCNativeSnapshot @end
// Host-only bridge: exercise the actual parser/catalog without linking the
// native game adapter or including any game resources in the repository.
@implementation IDCNativeBridge
- (NSString *)executableUUID { return @"HOST-CHECK"; }
- (BOOL)isSupportedBuild { return YES; }
- (IDCNativeSnapshot *)refreshSnapshot { return nil; }
- (BOOL)beginConsolePause { return YES; }
- (void)endConsolePause {}
- (void)cancelConsolePauseOwnership {}
- (NSString *)giveCollectible:(NSInteger)value { (void)value; return nil; }
- (NSString *)removeCollectible:(NSInteger)value { (void)value; return nil; }
- (NSString *)spawnEntityType:(NSInteger)t variant:(NSInteger)v subtype:(NSInteger)s {
    (void)t; (void)v; (void)s; return nil;
}
- (NSString *)spawnPillEffect:(NSInteger)e horse:(BOOL)h resolvedColor:(NSInteger *)c {
    (void)e; (void)h; (void)c; return nil;
}
- (NSString *)rewind { return nil; }
- (NSString *)restart { return nil; }
@end
@interface CommandBridge : IDCNativeBridge
@property(nonatomic, strong) IDCNativeSnapshot *snapshot;
@property(nonatomic, copy) NSString *restartError;
@property(nonatomic) NSUInteger restarts;
@end
@implementation CommandBridge
- (IDCNativeSnapshot *)refreshSnapshot { return self.snapshot; }
- (NSString *)restart { self.restarts++; return self.restartError; }
@end
int main(void) {
    @autoreleasepool {
        CommandBridge *bridge = [CommandBridge new];
        bridge.snapshot = [IDCNativeSnapshot new];
        IDCCommandEngine *engine = [[IDCCommandEngine alloc] initWithBridge:bridge catalog:[IDCItemCatalog new]];
        assert([[engine executeInput:@"help"].output containsString:@"restart"]);
        assert([[engine executeInput:@"help rs"].output containsString:@"Aliases: rs"]);
        NSArray *suggestions = [engine suggestionsForInput:@"rs" limit:20];
        assert(suggestions.count == 1);
        assert([((IDCCommandSuggestion *)suggestions[0]).replacementText isEqualToString:@"restart "]);
        assert([[engine executeInput:@"restart"].output containsString:@"active run"]);
        assert(bridge.restarts == 0);
        bridge.snapshot.inGame = YES;
        assert([[engine executeInput:@"rs extra"].output containsString:@"Usage:"]);
        assert(bridge.restarts == 0);
        bridge.restartError = @"Pause the run before using modifying commands.";
        IDCCommandResult *result = [engine executeInput:@"rs"];
        assert(result.action == IDCCommandActionNone && [result.output hasPrefix:@"Error:"]);
        bridge.restartError = nil;
        assert([engine executeInput:@"restart"].action == IDCCommandActionClose);
        assert([engine executeInput:@"  RS  "].action == IDCCommandActionClose);
        assert(bridge.restarts == 3);
        assert([[engine executeInput:@"help r"].output containsString:@"remove"]);
        assert([[engine executeInput:@"help rewind"].output containsString:@"Glowing Hourglass"]);
        puts("Command checks passed: restart/rs, help, suggestions, argument rejection, errors, close-on-success");
    }
}
