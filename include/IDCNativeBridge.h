#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface IDCNativeSnapshot : NSObject
@property(nonatomic) BOOL supportedBuild;
@property(nonatomic) BOOL inGame;
@property(nonatomic) BOOL pauseStateAvailable;
@property(nonatomic) BOOL paused;
@property(nonatomic, copy) NSString *executableUUID;
@property(nonatomic) uint32_t runSeed;
@property(nonatomic) NSInteger roomType;
@property(nonatomic) NSInteger playerType;
@property(nonatomic) float playerX;
@property(nonatomic) float playerY;
@property(nonatomic, copy) NSDictionary<NSNumber *, NSNumber *> *collectibleCounts;
@end

@interface IDCNativeBridge : NSObject
@property(nonatomic, copy, readonly) NSString *executableUUID;
@property(nonatomic, readonly, getter=isSupportedBuild) BOOL supportedBuild;

- (IDCNativeSnapshot *)refreshSnapshot;
- (nullable NSString *)giveCollectible:(NSInteger)collectibleID;
- (nullable NSString *)removeCollectible:(NSInteger)collectibleID;
@end

NS_ASSUME_NONNULL_END
