#import <Foundation/Foundation.h>

@class IDCItemCatalog;
@class IDCNativeBridge;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, IDCCommandAction) {
    IDCCommandActionNone = 0,
    IDCCommandActionClear,
    IDCCommandActionClose,
    IDCCommandActionHistory,
};

@interface IDCCommandResult : NSObject
@property(nonatomic, copy) NSString *output;
@property(nonatomic) IDCCommandAction action;
@end

@interface IDCCommandSuggestion : NSObject
@property(nonatomic, copy) NSString *displayText;
@property(nonatomic, copy) NSString *replacementText;
@end

@interface IDCCommandEngine : NSObject
- (instancetype)initWithBridge:(IDCNativeBridge *)bridge catalog:(IDCItemCatalog *)catalog;
- (IDCCommandResult *)executeInput:(NSString *)input;
- (NSArray<IDCCommandSuggestion *> *)suggestionsForInput:(NSString *)input limit:(NSUInteger)limit;
@end

NS_ASSUME_NONNULL_END
