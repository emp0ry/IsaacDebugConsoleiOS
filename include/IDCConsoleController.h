#import <Foundation/Foundation.h>

@class IDCCommandEngine;
@class IDCNativeBridge;

NS_ASSUME_NONNULL_BEGIN

@interface IDCConsoleController : NSObject
- (instancetype)initWithBridge:(IDCNativeBridge *)bridge engine:(IDCCommandEngine *)engine;
- (void)start;
@end

NS_ASSUME_NONNULL_END
