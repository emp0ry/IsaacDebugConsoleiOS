#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface IDCItemRecord : NSObject
@property(nonatomic) NSInteger identifier;
@property(nonatomic, copy) NSString *name;
@property(nonatomic, copy) NSString *kind;
@end

@interface IDCItemCatalog : NSObject
@property(nonatomic, readonly) NSUInteger count;

- (nullable IDCItemRecord *)recordForIdentifier:(NSInteger)identifier;
- (nullable IDCItemRecord *)recordForSpecifier:(NSString *)specifier
                                          error:(NSString * _Nullable * _Nullable)error;
- (NSArray<IDCItemRecord *> *)recordsMatching:(NSString *)query limit:(NSUInteger)limit;
@end

NS_ASSUME_NONNULL_END
