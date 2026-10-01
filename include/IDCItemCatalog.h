#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface IDCItemRecord : NSObject
@property(nonatomic) NSInteger identifier;
@property(nonatomic, copy) NSString *name;
@property(nonatomic, copy) NSString *kind;
@end

@interface IDCItemCatalog : NSObject
@property(nonatomic, readonly) NSUInteger count;
@property(nonatomic, readonly) NSUInteger trinketCount;
@property(nonatomic, readonly) NSUInteger pocketItemCount;
@property(nonatomic, readonly) NSUInteger pillEffectCount;

- (nullable IDCItemRecord *)recordForIdentifier:(NSInteger)identifier;
- (nullable IDCItemRecord *)recordForSpecifier:(NSString *)specifier
                                          error:(NSString * _Nullable * _Nullable)error;
- (NSArray<IDCItemRecord *> *)recordsMatching:(NSString *)query limit:(NSUInteger)limit;

- (nullable IDCItemRecord *)trinketForSpecifier:(NSString *)specifier
                                           error:(NSString * _Nullable * _Nullable)error;
- (NSArray<IDCItemRecord *> *)trinketsMatching:(NSString *)query limit:(NSUInteger)limit;

- (nullable IDCItemRecord *)pocketItemForSpecifier:(NSString *)specifier
                                               kind:(nullable NSString *)kind
                                              error:(NSString * _Nullable * _Nullable)error;
- (NSArray<IDCItemRecord *> *)pocketItemsMatching:(NSString *)query
                                              kind:(nullable NSString *)kind
                                             limit:(NSUInteger)limit;

- (nullable IDCItemRecord *)pillEffectForSpecifier:(NSString *)specifier
                                              error:(NSString * _Nullable * _Nullable)error;
- (NSArray<IDCItemRecord *> *)pillEffectsMatching:(NSString *)query limit:(NSUInteger)limit;
@end

NS_ASSUME_NONNULL_END
