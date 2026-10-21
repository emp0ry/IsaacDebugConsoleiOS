#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Return YES only when the console actually handled the shortcut.
@interface IDCHotkey : NSObject
- (instancetype)initWithHandler:(BOOL (^)(void))handler;
- (void)start;
@end

NS_ASSUME_NONNULL_END
