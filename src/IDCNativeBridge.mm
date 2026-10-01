#import "IDCNativeBridge.h"
#import "IDCLogger.h"

#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach.h>

#include <array>
#include <cmath>
#include <cstring>
#include <vector>

namespace {
constexpr const char *kSupportedUUID = "F4357753-A25F-30EE-BACF-63709F902895";
constexpr const char *kPlayerRTTIName = "N15IsaacRepentance13Entity_PlayerE";
constexpr size_t kMaximumCollectibleID = 732;
constexpr size_t kMaxPlayers = 8;
constexpr size_t kMaxVTables = 8;

constexpr uintptr_t kGameGlobalOffset = 0xac3b90;
constexpr size_t kGameCurrentRoomOffset = 0x21550;
constexpr size_t kGameRunSeedOffset = 0x25d44;
constexpr size_t kGamePauseStateOffset = 0x10dfd8;
constexpr size_t kGameItemPoolOffset = 0x242c0;
constexpr size_t kGameEntityFactoryOffset = 0x1cf430;
constexpr size_t kGamePlayerVectorScanLimit = 512 * 1024;
constexpr size_t kItemPoolPillEffectsOffset = 0xa2c;
constexpr uint32_t kStandardPillColorCount = 13;
constexpr uint32_t kHorsePillFlag = 1u << 11;

constexpr size_t kEntityTypeOffset = 0x38;
constexpr size_t kEntityPositionOffset = 0x310;
constexpr size_t kPlayerCollectibleCountsOffset = 0x1ab8;

constexpr size_t kRoomDescriptorOffset = 0x8;
constexpr size_t kRoomDescriptorDataOffset = 0x10;
constexpr size_t kRoomConfigTypeOffset = 0x8;

// Reverse-verified function RVAs for UUID F4357753-A25F-30EE-BACF-63709F902895.
constexpr uintptr_t kAddCollectibleOffset = 0x500588;
constexpr uintptr_t kRemoveCollectibleOffset = 0x5051e0;
constexpr uintptr_t kGameSpawnOffset = 0x88fcbc;
constexpr uintptr_t kUseActiveItemOffset = 0x580a28;
constexpr uint32_t kAddCollectiblePrologue[] = {0xd10483ff, 0x6d0a2beb, 0x6d0b23e9};
constexpr uint32_t kRemoveCollectiblePrologue[] = {0xd10283ff, 0xa9046ffc, 0xa90567fa};
constexpr uint32_t kGameSpawnPrologue[] = {
    0xd10283ff, 0xa9046ffc, 0xa90567fa, 0xa9065ff8
};
constexpr uint32_t kUseActiveItemPrologue[] = {
    0x6db733ed, 0x6d012beb, 0x6d0223e9, 0xa9036ffc
};

constexpr int kPickupEntityType = 5;
constexpr int kPillPickupVariant = 70;
constexpr int kGlowingHourglassCollectible = 422;

struct NativeVector {
    float x = 0;
    float y = 0;
};

struct RemotePointerVector {
    uintptr_t begin = 0;
    uintptr_t end = 0;
    uintptr_t capacity = 0;
};

struct NativePlayer {
    vm_address_t address = 0;
    int32_t playerType = 0;
    float x = 0;
    float y = 0;
};

struct NativePlayers {
    std::array<NativePlayer, kMaxPlayers> values{};
    size_t count = 0;
};

static bool ReadMemory(vm_address_t address, void *destination, vm_size_t size) {
    if (!address || !destination || !size) return false;
    vm_size_t copied = 0;
    return vm_read_overwrite(mach_task_self(), address, size,
                             reinterpret_cast<vm_address_t>(destination), &copied) == KERN_SUCCESS &&
        copied == size;
}

static NSString *UUIDForHeader(const mach_header_64 *header) {
    if (!header || header->magic != MH_MAGIC_64 || header->ncmds > 65536 ||
        header->sizeofcmds > 64 * 1024 * 1024) return @"UNKNOWN";
    const uint8_t *cursor = reinterpret_cast<const uint8_t *>(header + 1);
    const uint8_t *end = cursor + header->sizeofcmds;
    for (uint32_t index = 0; index < header->ncmds; ++index) {
        if (cursor > end || static_cast<size_t>(end - cursor) < sizeof(load_command)) break;
        const load_command *command = reinterpret_cast<const load_command *>(cursor);
        if (command->cmdsize < sizeof(load_command) ||
            static_cast<size_t>(end - cursor) < command->cmdsize) break;
        if (command->cmd == LC_UUID && command->cmdsize >= sizeof(uuid_command)) {
            const unsigned char *u = reinterpret_cast<const uuid_command *>(cursor)->uuid;
            return [NSString stringWithFormat:
                @"%02X%02X%02X%02X-%02X%02X-%02X%02X-%02X%02X-%02X%02X%02X%02X%02X%02X",
                u[0], u[1], u[2], u[3], u[4], u[5], u[6], u[7], u[8], u[9],
                u[10], u[11], u[12], u[13], u[14], u[15]];
        }
        cursor += command->cmdsize;
    }
    return @"UNKNOWN";
}

static const mach_header_64 *FindIsaacImage(intptr_t *slideOut) {
    NSString *supported = [NSString stringWithUTF8String:kSupportedUUID];
    for (uint32_t index = 0; index < _dyld_image_count(); ++index) {
        const mach_header_64 *header = reinterpret_cast<const mach_header_64 *>(
            _dyld_get_image_header(index));
        if ([UUIDForHeader(header) caseInsensitiveCompare:supported] == NSOrderedSame) {
            if (slideOut) *slideOut = _dyld_get_image_vmaddr_slide(index);
            return header;
        }
    }
    if (slideOut) *slideOut = 0;
    return nullptr;
}

static void ForEachIsaacSegment(
    const mach_header_64 *header, intptr_t slide,
    void (^block)(const uint8_t *address, size_t size, vm_prot_t protection)) {
    if (!header || header->magic != MH_MAGIC_64) return;
    const uint8_t *cursor = reinterpret_cast<const uint8_t *>(header + 1);
    for (uint32_t index = 0; index < header->ncmds; ++index) {
        const load_command *command = reinterpret_cast<const load_command *>(cursor);
        if (command->cmd == LC_SEGMENT_64 && command->cmdsize >= sizeof(segment_command_64)) {
            const segment_command_64 *segment =
                reinterpret_cast<const segment_command_64 *>(cursor);
            if (segment->vmsize && strcmp(segment->segname, "__LINKEDIT") != 0) {
                block(reinterpret_cast<const uint8_t *>(segment->vmaddr + slide),
                      static_cast<size_t>(segment->vmsize), segment->initprot);
            }
        }
        if (!command->cmdsize) break;
        cursor += command->cmdsize;
    }
}

static std::array<uintptr_t, kMaxVTables> LocatePlayerVTables(
    const mach_header_64 *header, intptr_t slide, size_t& outputCount) {
    __block std::array<uintptr_t, kMaxVTables> output{};
    outputCount = 0;
    __block uintptr_t typeNameAddress = 0;
    const size_t nameLength = strlen(kPlayerRTTIName) + 1;
    ForEachIsaacSegment(header, slide,
        ^(const uint8_t *address, size_t size, vm_prot_t protection) {
        if (typeNameAddress || !(protection & VM_PROT_READ) ||
            (protection & VM_PROT_WRITE)) return;
        for (size_t offset = 0; offset + nameLength <= size; ++offset) {
            if (memcmp(address + offset, kPlayerRTTIName, nameLength) == 0) {
                typeNameAddress = reinterpret_cast<uintptr_t>(address + offset);
                return;
            }
        }
    });
    if (!typeNameAddress) return output;

    __block std::array<uintptr_t, 8> typeInfos{};
    __block size_t typeInfoCount = 0;
    ForEachIsaacSegment(header, slide,
        ^(const uint8_t *address, size_t size, vm_prot_t protection) {
        if (!(protection & VM_PROT_READ)) return;
        for (size_t offset = sizeof(uintptr_t); offset + sizeof(uintptr_t) <= size;
             offset += sizeof(uintptr_t)) {
            uintptr_t value = 0;
            memcpy(&value, address + offset, sizeof(value));
            if (value == typeNameAddress && typeInfoCount < typeInfos.size()) {
                typeInfos[typeInfoCount++] =
                    reinterpret_cast<uintptr_t>(address + offset - sizeof(uintptr_t));
            }
        }
    });

    ForEachIsaacSegment(header, slide,
        ^(const uint8_t *address, size_t size, vm_prot_t protection) {
        if (!(protection & VM_PROT_READ)) return;
        for (size_t offset = sizeof(uintptr_t); offset + 2 * sizeof(uintptr_t) <= size;
             offset += sizeof(uintptr_t)) {
            uintptr_t value = 0;
            memcpy(&value, address + offset, sizeof(value));
            for (size_t index = 0; index < typeInfoCount && outputCount < output.size(); ++index) {
                if (value != typeInfos[index]) continue;
                intptr_t offsetToTop = -1;
                uintptr_t firstMethod = 0;
                memcpy(&offsetToTop, address + offset - sizeof(uintptr_t), sizeof(offsetToTop));
                memcpy(&firstMethod, address + offset + sizeof(uintptr_t), sizeof(firstMethod));
                if (offsetToTop == 0 && firstMethod) {
                    output[outputCount++] =
                        reinterpret_cast<uintptr_t>(address + offset + sizeof(uintptr_t));
                }
            }
        }
    });
    return output;
}

static bool IsPlayerVTable(const std::array<uintptr_t, kMaxVTables>& vtables,
                           size_t count, uintptr_t value) {
    for (size_t index = 0; index < count; ++index) {
        if (vtables[index] == value) return true;
    }
    return false;
}

static bool ReadPlayer(const std::array<uintptr_t, kMaxVTables>& vtables,
                       size_t vtableCount, vm_address_t address, NativePlayer& player) {
    uintptr_t vtable = 0;
    int32_t identity[3]{};
    float position[2]{};
    if (!ReadMemory(address, &vtable, sizeof(vtable)) ||
        !IsPlayerVTable(vtables, vtableCount, vtable) ||
        !ReadMemory(address + kEntityTypeOffset, identity, sizeof(identity)) ||
        !ReadMemory(address + kEntityPositionOffset, position, sizeof(position))) return false;
    if (identity[0] != 1 || identity[1] != 0 || identity[2] < 0 || identity[2] >= 100 ||
        !std::isfinite(position[0]) || !std::isfinite(position[1]) ||
        std::fabs(position[0]) > 4096 || std::fabs(position[1]) > 4096) return false;
    player = {address, identity[2], position[0], position[1]};
    return true;
}

static bool ReadPlayerVector(const std::array<uintptr_t, kMaxVTables>& vtables,
                             size_t vtableCount, vm_address_t vectorAddress,
                             NativePlayers& players) {
    RemotePointerVector vector;
    if (!ReadMemory(vectorAddress, &vector, sizeof(vector)) || !vector.begin ||
        vector.end <= vector.begin || vector.capacity < vector.end ||
        (vector.end - vector.begin) % sizeof(uintptr_t) != 0) return false;
    const size_t count = (vector.end - vector.begin) / sizeof(uintptr_t);
    const size_t capacity = (vector.capacity - vector.begin) / sizeof(uintptr_t);
    if (!count || count > kMaxPlayers || capacity < count || capacity > 64) return false;
    std::array<uintptr_t, kMaxPlayers> addresses{};
    if (!ReadMemory(vector.begin, addresses.data(), count * sizeof(uintptr_t))) return false;
    NativePlayers result;
    for (size_t index = 0; index < count; ++index) {
        NativePlayer player;
        if (!ReadPlayer(vtables, vtableCount, addresses[index], player)) return false;
        result.values[result.count++] = player;
    }
    players = result;
    return true;
}

static bool ReadCollectibles(vm_address_t player,
                             std::array<int32_t, kMaximumCollectibleID + 1>& counts) {
    uintptr_t table = 0;
    if (!ReadMemory(player + kPlayerCollectibleCountsOffset, &table, sizeof(table)) ||
        !table || !ReadMemory(table, counts.data(), sizeof(counts))) return false;
    uint64_t total = 0;
    for (int32_t count : counts) {
        if (count < 0 || count > 999) return false;
        total += static_cast<uint32_t>(count);
        if (total > 4096) return false;
    }
    return true;
}

static bool MatchPrologue(const mach_header_64 *header, uintptr_t offset,
                          const uint32_t *expected, size_t count) {
    std::array<uint32_t, 4> actual{};
    if (count > actual.size() || !ReadMemory(
            reinterpret_cast<vm_address_t>(header) + offset, actual.data(),
            count * sizeof(uint32_t))) return false;
    return memcmp(actual.data(), expected, count * sizeof(uint32_t)) == 0;
}
}  // namespace

@implementation IDCNativeSnapshot
- (instancetype)init {
    self = [super init];
    if (self) {
        _executableUUID = @"UNKNOWN";
        _collectibleCounts = @{};
    }
    return self;
}
@end

@interface IDCNativeBridge () {
    const mach_header_64 *_isaacHeader;
    intptr_t _isaacSlide;
    std::array<uintptr_t, kMaxVTables> _playerVTables;
    size_t _playerVTableCount;
    NSUInteger _playerVectorOffset;
    vm_address_t _currentPlayer;
    IDCNativeSnapshot *_lastSnapshot;
}
@property(nonatomic, copy) NSString *executableUUID;
@property(nonatomic, getter=isSupportedBuild) BOOL supportedBuild;
@end

@implementation IDCNativeBridge

- (instancetype)init {
    self = [super init];
    if (self) {
        _playerVectorOffset = NSUIntegerMax;
        _isaacHeader = FindIsaacImage(&_isaacSlide);
        _executableUUID = UUIDForHeader(_isaacHeader);
        NSString *supported = [NSString stringWithUTF8String:kSupportedUUID];
        _supportedBuild = _isaacHeader &&
            [_executableUUID caseInsensitiveCompare:supported] == NSOrderedSame;
        if (_supportedBuild) {
            _playerVTables = LocatePlayerVTables(
                _isaacHeader, _isaacSlide, _playerVTableCount);
            _supportedBuild = _playerVTableCount > 0;
        }
        IDCLog(@"native bridge %@ for UUID %@ (%lu player vtables)",
               _supportedBuild ? @"enabled" : @"disabled", _executableUUID,
               static_cast<unsigned long>(_playerVTableCount));
    }
    return self;
}

- (BOOL)readGameAddress:(vm_address_t *)gameAddress {
    if (!_supportedBuild || !_isaacHeader || !gameAddress) return NO;
    uintptr_t game = 0;
    if (!ReadMemory(reinterpret_cast<vm_address_t>(_isaacHeader) + kGameGlobalOffset,
                    &game, sizeof(game)) || !game) return NO;
    *gameAddress = static_cast<vm_address_t>(game);
    return YES;
}

- (BOOL)readSpawnContextAddress:(vm_address_t *)gameAddress error:(NSString **)error {
    if (!_supportedBuild || !_isaacHeader || !gameAddress) {
        if (error) *error = @"The native spawn context is unavailable.";
        return NO;
    }
    vm_address_t game = 0;
    if (![self readGameAddress:&game]) {
        if (error) *error = @"The active Game object is unavailable.";
        return NO;
    }
    uintptr_t factory = 0;
    uintptr_t room = 0;
    if (!ReadMemory(game + kGameEntityFactoryOffset, &factory, sizeof(factory)) ||
        factory < 0x100000000ULL || factory == UINTPTR_MAX ||
        !ReadMemory(game + kGameCurrentRoomOffset, &room, sizeof(room)) ||
        room < 0x100000000ULL) {
        if (error) *error = @"Isaac's spawn context is not ready in this room.";
        return NO;
    }
    uint8_t factoryProbe = 0;
    uint8_t roomProbe = 0;
    if (!ReadMemory(factory, &factoryProbe, sizeof(factoryProbe)) ||
        !ReadMemory(room, &roomProbe, sizeof(roomProbe))) {
        if (error) *error = @"Isaac's spawn context failed memory validation.";
        return NO;
    }
    *gameAddress = game;
    return YES;
}

- (BOOL)resolvePlayersFromGame:(vm_address_t)game players:(NativePlayers&)players {
    if (_playerVectorOffset != NSUIntegerMax &&
        ReadPlayerVector(_playerVTables, _playerVTableCount,
                         game + _playerVectorOffset, players)) return YES;
    _playerVectorOffset = NSUIntegerMax;

    vm_address_t regionAddress = game;
    vm_size_t regionSize = 0;
    vm_region_basic_info_data_64_t info{};
    mach_msg_type_number_t infoCount = VM_REGION_BASIC_INFO_COUNT_64;
    mach_port_t objectName = MACH_PORT_NULL;
    kern_return_t status = vm_region_64(
        mach_task_self(), &regionAddress, &regionSize, VM_REGION_BASIC_INFO_64,
        reinterpret_cast<vm_region_info_t>(&info), &infoCount, &objectName);
    if (objectName != MACH_PORT_NULL) mach_port_deallocate(mach_task_self(), objectName);
    if (status != KERN_SUCCESS || regionAddress > game ||
        !(info.protection & VM_PROT_READ) || regionSize <= game - regionAddress) return NO;
    vm_size_t available = regionSize - (game - regionAddress);
    vm_size_t scanSize = MIN(available, static_cast<vm_size_t>(kGamePlayerVectorScanLimit));
    if (scanSize < sizeof(RemotePointerVector)) return NO;
    std::vector<uint8_t> bytes(static_cast<size_t>(scanSize));
    if (!ReadMemory(game, bytes.data(), scanSize)) return NO;
    for (size_t offset = 0; offset + sizeof(RemotePointerVector) <= bytes.size();
         offset += sizeof(uintptr_t)) {
        RemotePointerVector vector;
        memcpy(&vector, bytes.data() + offset, sizeof(vector));
        if (!vector.begin || vector.end <= vector.begin || vector.capacity < vector.end ||
            (vector.end - vector.begin) % sizeof(uintptr_t) != 0) continue;
        size_t count = (vector.end - vector.begin) / sizeof(uintptr_t);
        if (!count || count > kMaxPlayers) continue;
        if (ReadPlayerVector(_playerVTables, _playerVTableCount, game + offset, players)) {
            _playerVectorOffset = offset;
            IDCLog(@"player vector resolved at Game + 0x%lx", (unsigned long)offset);
            return YES;
        }
    }
    return NO;
}

- (IDCNativeSnapshot *)refreshSnapshot {
    IDCNativeSnapshot *snapshot = [IDCNativeSnapshot new];
    snapshot.supportedBuild = self.supportedBuild;
    snapshot.executableUUID = self.executableUUID;
    _currentPlayer = 0;
    vm_address_t game = 0;
    if (![self readGameAddress:&game]) {
        _lastSnapshot = snapshot;
        return snapshot;
    }

    uint32_t seed = 0;
    if (ReadMemory(game + kGameRunSeedOffset, &seed, sizeof(seed))) snapshot.runSeed = seed;
    int32_t pauseState = -1;
    if (ReadMemory(game + kGamePauseStateOffset, &pauseState, sizeof(pauseState)) &&
        pauseState >= 0 && pauseState <= 3) {
        snapshot.pauseStateAvailable = YES;
        snapshot.paused = pauseState > 0;
    }

    uintptr_t room = 0;
    uintptr_t descriptor = 0;
    uintptr_t roomData = 0;
    int32_t roomType = 0;
    if (ReadMemory(game + kGameCurrentRoomOffset, &room, sizeof(room)) && room &&
        ReadMemory(room + kRoomDescriptorOffset, &descriptor, sizeof(descriptor)) && descriptor &&
        ReadMemory(descriptor + kRoomDescriptorDataOffset, &roomData, sizeof(roomData)) && roomData &&
        ReadMemory(roomData + kRoomConfigTypeOffset, &roomType, sizeof(roomType)) &&
        roomType >= 1 && roomType <= 29) snapshot.roomType = roomType;

    NativePlayers players;
    if (![self resolvePlayersFromGame:game players:players] || !players.count) {
        _lastSnapshot = snapshot;
        return snapshot;
    }
    const NativePlayer& player = players.values[0];
    _currentPlayer = player.address;
    snapshot.inGame = YES;
    snapshot.playerType = player.playerType;
    snapshot.playerX = player.x;
    snapshot.playerY = player.y;

    std::array<int32_t, kMaximumCollectibleID + 1> counts{};
    if (ReadCollectibles(player.address, counts)) {
        NSMutableDictionary<NSNumber *, NSNumber *> *inventory = [NSMutableDictionary dictionary];
        for (size_t identifier = 1; identifier < counts.size(); ++identifier) {
            if (counts[identifier] > 0) inventory[@(identifier)] = @(counts[identifier]);
        }
        snapshot.collectibleCounts = inventory.copy;
    }
    _lastSnapshot = snapshot;
    return snapshot;
}

- (NSString *)validatePausedNativeAction {
    if (!self.supportedBuild) return @"Unsupported Isaac executable; mutation disabled.";
    IDCNativeSnapshot *snapshot = [self refreshSnapshot];
    if (!snapshot.inGame || !_currentPlayer) return @"No active player was found.";
    if (!snapshot.pauseStateAvailable || !snapshot.paused) {
        return @"Pause the run before using modifying commands.";
    }
    return nil;
}

- (BOOL)matchesFunctionAtOffset:(uintptr_t)offset
                       prologue:(const uint32_t *)prologue
                          count:(size_t)count {
    return _isaacHeader && MatchPrologue(_isaacHeader, offset, prologue, count);
}

- (NSString *)validateCollectible:(NSInteger)collectibleID
                    functionOffset:(uintptr_t)functionOffset
                       prologue:(const uint32_t *)prologue
                           count:(size_t)count {
    if (collectibleID < 1 || collectibleID > (NSInteger)kMaximumCollectibleID) {
        return [NSString stringWithFormat:@"Collectible ID must be between 1 and %zu.",
                                          kMaximumCollectibleID];
    }
    NSString *error = [self validatePausedNativeAction];
    if (error) return error;
    if (![self matchesFunctionAtOffset:functionOffset prologue:prologue count:count]) {
        return @"Native command signature failed validation; mutation disabled.";
    }
    return nil;
}

- (NSString *)giveCollectible:(NSInteger)collectibleID {
    NSString *error = [self validateCollectible:collectibleID
                                  functionOffset:kAddCollectibleOffset
                                        prologue:kAddCollectiblePrologue
                                           count:sizeof(kAddCollectiblePrologue) /
                                               sizeof(kAddCollectiblePrologue[0])];
    if (error) return error;
    using AddCollectible = void (*)(void *, int, int, bool, int, int, int);
    AddCollectible function = reinterpret_cast<AddCollectible>(
        reinterpret_cast<uintptr_t>(_isaacHeader) + kAddCollectibleOffset);
    function(reinterpret_cast<void *>(_currentPlayer), (int)collectibleID,
             0, true, 0, 0, 0);
    IDCNativeSnapshot *after = [self refreshSnapshot];
    if (after.collectibleCounts[@(collectibleID)].integerValue <= 0) {
        return @"The native AddCollectible call completed, but inventory verification failed.";
    }
    IDCLog(@"giveitem c%ld verified", (long)collectibleID);
    return nil;
}

- (NSString *)removeCollectible:(NSInteger)collectibleID {
    NSString *error = [self validateCollectible:collectibleID
                                  functionOffset:kRemoveCollectibleOffset
                                        prologue:kRemoveCollectiblePrologue
                                           count:sizeof(kRemoveCollectiblePrologue) /
                                               sizeof(kRemoveCollectiblePrologue[0])];
    if (error) return error;
    IDCNativeSnapshot *before = _lastSnapshot ?: [self refreshSnapshot];
    NSInteger oldCount = before.collectibleCounts[@(collectibleID)].integerValue;
    if (oldCount <= 0) return @"The player does not own that collectible.";
    using RemoveCollectible = void (*)(void *, unsigned int, bool, unsigned int, bool);
    RemoveCollectible function = reinterpret_cast<RemoveCollectible>(
        reinterpret_cast<uintptr_t>(_isaacHeader) + kRemoveCollectibleOffset);
    function(reinterpret_cast<void *>(_currentPlayer), (unsigned int)collectibleID,
             false, UINT32_MAX, true);
    IDCNativeSnapshot *after = [self refreshSnapshot];
    if (after.collectibleCounts[@(collectibleID)].integerValue >= oldCount) {
        return @"The native RemoveCollectible call completed, but inventory verification failed.";
    }
    IDCLog(@"remove c%ld verified", (long)collectibleID);
    return nil;
}

- (NSString *)spawnEntityType:(NSInteger)type
                       variant:(NSInteger)variant
                       subtype:(NSInteger)subtype {
    if (!((type >= 2 && type <= 9) || type == 1000)) {
        return @"Supported entity types are 2 through 9 and 1000.";
    }
    if (variant < 0 || variant > 9999) return @"Entity variant must be between 0 and 9999.";
    if (subtype < 0 || subtype > 9999) return @"Entity subtype must be between 0 and 9999.";
    NSString *error = [self validatePausedNativeAction];
    if (error) return error;
    if (![self matchesFunctionAtOffset:kGameSpawnOffset
                              prologue:kGameSpawnPrologue
                                 count:sizeof(kGameSpawnPrologue) /
                                     sizeof(kGameSpawnPrologue[0])]) {
        return @"Native spawn signature failed validation; spawning disabled.";
    }
    vm_address_t game = 0;
    if (![self readSpawnContextAddress:&game error:&error]) return error;

    NativeVector position{_lastSnapshot.playerX, _lastSnapshot.playerY};
    position.x += position.x < 320.0f ? 64.0f : -64.0f;
    NativeVector velocity{};
    uint32_t seed = arc4random();
    if (!seed) seed = 1;
    using GameSpawn = void *(*)(void *, unsigned int, unsigned int,
                                const NativeVector *, const NativeVector *, void *,
                                unsigned int, unsigned int, unsigned int);
    GameSpawn function = reinterpret_cast<GameSpawn>(
        reinterpret_cast<uintptr_t>(_isaacHeader) + kGameSpawnOffset);
    void *entity = function(reinterpret_cast<void *>(game), (unsigned int)type,
                            (unsigned int)variant, &position, &velocity, nullptr,
                            (unsigned int)subtype, seed, 0);
    if (!entity) return @"Isaac rejected the spawn request.";
    int32_t identity[3]{};
    if (!ReadMemory(reinterpret_cast<vm_address_t>(entity) + kEntityTypeOffset,
                    identity, sizeof(identity)) || identity[0] != type ||
        identity[1] != variant || identity[2] != subtype) {
        return @"The entity was created, but identity verification failed.";
    }
    IDCLog(@"spawn verified: %ld.%ld.%ld", (long)type, (long)variant, (long)subtype);
    return nil;
}

- (NSString *)spawnPillEffect:(NSInteger)effectID
                          horse:(BOOL)horse
                  resolvedColor:(NSInteger *)resolvedColor {
    if (effectID < 0 || effectID > 49) return @"Pill effect ID must be between 0 and 49.";
    NSString *error = [self validatePausedNativeAction];
    if (error) return error;
    vm_address_t game = 0;
    if (![self readGameAddress:&game]) return @"The active Game object is unavailable.";
    uintptr_t itemPool = game + kGameItemPoolOffset;
    NSInteger color = 0;
    for (uint32_t candidate = 1; candidate <= kStandardPillColorCount; ++candidate) {
        int32_t mappedEffect = -1;
        if (ReadMemory(itemPool + kItemPoolPillEffectsOffset +
                           candidate * sizeof(mappedEffect),
                       &mappedEffect, sizeof(mappedEffect)) && mappedEffect == effectID) {
            color = candidate;
            break;
        }
    }
    if (!color) return @"That pill effect is not present in this run's pill pool.";
    NSInteger rawSubtype = color | (horse ? kHorsePillFlag : 0);
    error = [self spawnEntityType:kPickupEntityType variant:kPillPickupVariant
                          subtype:rawSubtype];
    if (!error && resolvedColor) *resolvedColor = color;
    return error;
}

- (NSString *)rewind {
    NSString *error = [self validatePausedNativeAction];
    if (error) return error;
    if (![self matchesFunctionAtOffset:kUseActiveItemOffset
                              prologue:kUseActiveItemPrologue
                                 count:sizeof(kUseActiveItemPrologue) /
                                     sizeof(kUseActiveItemPrologue[0])]) {
        return @"Native active-item signature failed validation; rewind disabled.";
    }
    using UseActiveItem = int32_t (*)(void *, int32_t, uint32_t, int32_t, int32_t);
    UseActiveItem function = reinterpret_cast<UseActiveItem>(
        reinterpret_cast<uintptr_t>(_isaacHeader) + kUseActiveItemOffset);
    vm_address_t player = _currentPlayer;
    _currentPlayer = 0;
    _lastSnapshot = nil;
    int32_t resultFlags = function(reinterpret_cast<void *>(player),
                                   kGlowingHourglassCollectible, 0, -1, 0);
    IDCLog(@"rewind requested through Glowing Hourglass native logic (result=%d)",
           resultFlags);
    return nil;
}

@end
