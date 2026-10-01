#import "IDCCommandEngine.h"
#import "IDCItemCatalog.h"
#import "IDCNativeBridge.h"

static NSString *const IDCVersion = @"0.1.0";

@implementation IDCCommandResult
@end

@implementation IDCCommandSuggestion
@end

@interface IDCCommandEngine ()
@property(nonatomic, strong) IDCNativeBridge *bridge;
@property(nonatomic, strong) IDCItemCatalog *catalog;
@property(nonatomic, copy) NSArray<NSDictionary<NSString *, id> *> *commands;
@end

@implementation IDCCommandEngine

- (instancetype)initWithBridge:(IDCNativeBridge *)bridge catalog:(IDCItemCatalog *)catalog {
    self = [super init];
    if (self) {
        _bridge = bridge;
        _catalog = catalog;
        _commands = @[
            @{ @"name": @"help", @"aliases": @[@"?"], @"usage": @"help [command]",
               @"summary": @"Show commands or detailed help" },
            @{ @"name": @"status", @"aliases": @[], @"usage": @"status",
               @"summary": @"Show native bridge and run state" },
            @{ @"name": @"seed", @"aliases": @[], @"usage": @"seed",
               @"summary": @"Show the current run seed" },
            @{ @"name": @"room", @"aliases": @[], @"usage": @"room",
               @"summary": @"Show the current native room type" },
            @{ @"name": @"position", @"aliases": @[@"pos"], @"usage": @"position",
               @"summary": @"Show player type and coordinates" },
            @{ @"name": @"inventory", @"aliases": @[@"inv"], @"usage": @"inventory",
               @"summary": @"List owned collectibles" },
            @{ @"name": @"items", @"aliases": @[@"find"], @"usage": @"items <name|id>",
               @"summary": @"Search collectible names and IDs" },
            @{ @"name": @"giveitem", @"aliases": @[@"g"],
               @"usage": @"giveitem <cID|name>",
               @"summary": @"Give a collectible through the native player function" },
            @{ @"name": @"remove", @"aliases": @[@"r"],
               @"usage": @"remove <cID|name>",
               @"summary": @"Remove one collectible through the native player function" },
            @{ @"name": @"history", @"aliases": @[], @"usage": @"history",
               @"summary": @"Print commands used in this session" },
            @{ @"name": @"clear", @"aliases": @[@"cls"], @"usage": @"clear",
               @"summary": @"Clear console output" },
            @{ @"name": @"version", @"aliases": @[], @"usage": @"version",
               @"summary": @"Show console version" },
            @{ @"name": @"close", @"aliases": @[@"exit"], @"usage": @"close",
               @"summary": @"Close the console panel" },
        ];
    }
    return self;
}

- (IDCCommandResult *)result:(NSString *)output action:(IDCCommandAction)action {
    IDCCommandResult *result = [IDCCommandResult new];
    result.output = output ?: @"";
    result.action = action;
    return result;
}

- (NSDictionary<NSString *, id> *)commandForToken:(NSString *)token {
    NSString *needle = token.lowercaseString;
    for (NSDictionary<NSString *, id> *command in self.commands) {
        if ([command[@"name"] isEqualToString:needle] ||
            [command[@"aliases"] containsObject:needle]) return command;
    }
    return nil;
}

- (NSArray<NSString *> *)commandAndArgument:(NSString *)input {
    NSString *trimmed = [input stringByTrimmingCharactersInSet:
        NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSRange whitespace = [trimmed rangeOfCharacterFromSet:NSCharacterSet.whitespaceCharacterSet];
    if (whitespace.location == NSNotFound) return @[trimmed.lowercaseString, @""];
    NSString *command = [[trimmed substringToIndex:whitespace.location] lowercaseString];
    NSString *argument = [[trimmed substringFromIndex:NSMaxRange(whitespace)]
        stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if ([argument hasPrefix:@"\""] && [argument hasSuffix:@"\""] && argument.length >= 2) {
        argument = [argument substringWithRange:NSMakeRange(1, argument.length - 2)];
    }
    return @[command, argument];
}

- (NSString *)roomName:(NSInteger)type {
    NSDictionary<NSNumber *, NSString *> *names = @{
        @1: @"Default", @2: @"Shop", @3: @"Error", @4: @"Treasure",
        @5: @"Boss", @6: @"Miniboss", @7: @"Secret", @8: @"Super Secret",
        @9: @"Arcade", @10: @"Curse", @11: @"Challenge", @12: @"Library",
        @13: @"Sacrifice", @14: @"Devil", @15: @"Angel", @16: @"Dungeon",
        @17: @"Boss Rush", @18: @"Isaac", @19: @"Barren", @20: @"Chest",
        @21: @"Dice", @22: @"Black Market", @23: @"Greed Exit", @24: @"Planetarium",
        @25: @"Teleporter", @26: @"Teleporter Exit", @27: @"Secret Exit",
        @28: @"Blue", @29: @"Ultra Secret"
    };
    return names[@(type)] ?: @"Unknown";
}

- (NSString *)itemLabel:(IDCItemRecord *)record {
    return [NSString stringWithFormat:@"c%ld — %@ (%@)", (long)record.identifier,
                                      record.name, record.kind];
}

- (IDCCommandResult *)executeInput:(NSString *)input {
    NSArray<NSString *> *parts = [self commandAndArgument:input];
    NSString *token = parts[0];
    NSString *argument = parts[1];
    if (!token.length) return [self result:@"" action:IDCCommandActionNone];
    NSDictionary<NSString *, id> *definition = [self commandForToken:token];
    if (!definition) {
        return [self result:[NSString stringWithFormat:
            @"Unknown command ‘%@’. Type help to list commands.", token]
                         action:IDCCommandActionNone];
    }
    NSString *command = definition[@"name"];

    if ([command isEqualToString:@"help"]) {
        if (argument.length) {
            NSDictionary *target = [self commandForToken:argument];
            if (!target) return [self result:@"Unknown help topic." action:IDCCommandActionNone];
            NSString *aliases = [target[@"aliases"] componentsJoinedByString:@", "];
            NSString *text = [NSString stringWithFormat:@"%@\n%@%@",
                target[@"usage"], target[@"summary"],
                aliases.length ? [NSString stringWithFormat:@"\nAliases: %@", aliases] : @""];
            return [self result:text action:IDCCommandActionNone];
        }
        NSMutableArray<NSString *> *lines = [NSMutableArray arrayWithObject:@"Available commands:"];
        for (NSDictionary *entry in self.commands) {
            [lines addObject:[NSString stringWithFormat:@"  %@ — %@",
                              entry[@"name"], entry[@"summary"]]];
        }
        [lines addObject:@"Tap a suggestion to fill the command. Modifying commands require a paused run."];
        return [self result:[lines componentsJoinedByString:@"\n"] action:IDCCommandActionNone];
    }
    if ([command isEqualToString:@"clear"]) {
        return [self result:@"" action:IDCCommandActionClear];
    }
    if ([command isEqualToString:@"close"]) {
        return [self result:@"" action:IDCCommandActionClose];
    }
    if ([command isEqualToString:@"history"]) {
        return [self result:@"" action:IDCCommandActionHistory];
    }
    if ([command isEqualToString:@"version"]) {
        return [self result:[NSString stringWithFormat:@"Isaac Debug Console iOS %@", IDCVersion]
                         action:IDCCommandActionNone];
    }

    IDCNativeSnapshot *snapshot = [self.bridge refreshSnapshot];
    if ([command isEqualToString:@"status"]) {
        NSString *state = snapshot.inGame ? (snapshot.paused ? @"paused" : @"playing") : @"menu";
        return [self result:[NSString stringWithFormat:
            @"Bridge: %@\nUUID: %@\nState: %@\nItem catalog: %lu entries",
            snapshot.supportedBuild ? @"supported" : @"disabled", snapshot.executableUUID,
            state, (unsigned long)self.catalog.count] action:IDCCommandActionNone];
    }
    if (!snapshot.inGame) {
        return [self result:@"This command requires an active run." action:IDCCommandActionNone];
    }
    if ([command isEqualToString:@"seed"]) {
        return [self result:snapshot.runSeed
            ? [NSString stringWithFormat:@"Run seed: %u (0x%08X)",
               snapshot.runSeed, snapshot.runSeed]
            : @"Run seed is unavailable." action:IDCCommandActionNone];
    }
    if ([command isEqualToString:@"room"]) {
        return [self result:snapshot.roomType
            ? [NSString stringWithFormat:@"Room type: %ld — %@", (long)snapshot.roomType,
               [self roomName:snapshot.roomType]]
            : @"Room type is unavailable." action:IDCCommandActionNone];
    }
    if ([command isEqualToString:@"position"]) {
        return [self result:[NSString stringWithFormat:@"Player %ld position: %.2f, %.2f",
            (long)snapshot.playerType, snapshot.playerX, snapshot.playerY]
                         action:IDCCommandActionNone];
    }
    if ([command isEqualToString:@"inventory"]) {
        if (!snapshot.collectibleCounts.count) {
            return [self result:@"No owned collectibles found." action:IDCCommandActionNone];
        }
        NSArray<NSNumber *> *identifiers = [snapshot.collectibleCounts.allKeys
            sortedArrayUsingSelector:@selector(compare:)];
        NSMutableArray<NSString *> *values = [NSMutableArray array];
        for (NSNumber *identifier in identifiers) {
            IDCItemRecord *record = [self.catalog recordForIdentifier:identifier.integerValue];
            NSString *name = record.name ?: [NSString stringWithFormat:@"Collectible %@", identifier];
            [values addObject:[NSString stringWithFormat:@"c%@ %@ ×%@", identifier, name,
                               snapshot.collectibleCounts[identifier]]];
        }
        return [self result:[values componentsJoinedByString:@"\n"] action:IDCCommandActionNone];
    }
    if ([command isEqualToString:@"items"]) {
        if (!argument.length) return [self result:@"Usage: items <name|id>" action:IDCCommandActionNone];
        NSArray<IDCItemRecord *> *matches = [self.catalog recordsMatching:argument limit:20];
        if (!matches.count) return [self result:@"No matching collectibles." action:IDCCommandActionNone];
        NSMutableArray<NSString *> *lines = [NSMutableArray array];
        for (IDCItemRecord *record in matches) [lines addObject:[self itemLabel:record]];
        return [self result:[lines componentsJoinedByString:@"\n"] action:IDCCommandActionNone];
    }
    if ([command isEqualToString:@"giveitem"] || [command isEqualToString:@"remove"]) {
        NSString *lookupError = nil;
        IDCItemRecord *record = [self.catalog recordForSpecifier:argument error:&lookupError];
        if (!record) return [self result:lookupError action:IDCCommandActionNone];
        NSString *nativeError = [command isEqualToString:@"giveitem"]
            ? [self.bridge giveCollectible:record.identifier]
            : [self.bridge removeCollectible:record.identifier];
        if (nativeError) return [self result:[@"Error: " stringByAppendingString:nativeError]
                                           action:IDCCommandActionNone];
        NSString *verb = [command isEqualToString:@"giveitem"] ? @"Added" : @"Removed";
        return [self result:[NSString stringWithFormat:@"%@ c%ld — %@",
                             verb, (long)record.identifier, record.name]
                         action:IDCCommandActionNone];
    }
    return [self result:@"Command is not implemented." action:IDCCommandActionNone];
}

- (IDCCommandSuggestion *)suggestion:(NSString *)display replacement:(NSString *)replacement {
    IDCCommandSuggestion *suggestion = [IDCCommandSuggestion new];
    suggestion.displayText = display;
    suggestion.replacementText = replacement;
    return suggestion;
}

- (NSArray<IDCCommandSuggestion *> *)suggestionsForInput:(NSString *)input limit:(NSUInteger)limit {
    NSString *trimmedLeading = [input stringByTrimmingCharactersInSet:
        NSCharacterSet.newlineCharacterSet];
    NSRange whitespace = [trimmedLeading rangeOfCharacterFromSet:NSCharacterSet.whitespaceCharacterSet];
    NSMutableArray<IDCCommandSuggestion *> *suggestions = [NSMutableArray array];
    if (whitespace.location == NSNotFound) {
        NSString *needle = trimmedLeading.lowercaseString;
        for (NSDictionary<NSString *, id> *command in self.commands) {
            NSString *name = command[@"name"];
            BOOL matches = !needle.length || [name hasPrefix:needle];
            if (!matches) {
                for (NSString *alias in command[@"aliases"]) {
                    if ([alias hasPrefix:needle]) { matches = YES; break; }
                }
            }
            if (!matches) continue;
            [suggestions addObject:[self suggestion:
                [NSString stringWithFormat:@"%@ — %@", command[@"usage"], command[@"summary"]]
                replacement:[name stringByAppendingString:@" "]]];
            if (suggestions.count >= limit) break;
        }
        return suggestions.copy;
    }

    NSString *token = [[trimmedLeading substringToIndex:whitespace.location] lowercaseString];
    NSDictionary *definition = [self commandForToken:token];
    if (!definition) return @[];
    NSString *command = definition[@"name"];
    NSString *argument = [[trimmedLeading substringFromIndex:NSMaxRange(whitespace)]
        stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    if ([command isEqualToString:@"giveitem"] || [command isEqualToString:@"remove"] ||
        [command isEqualToString:@"items"]) {
        for (IDCItemRecord *record in [self.catalog recordsMatching:argument limit:limit]) {
            NSString *replacement = [NSString stringWithFormat:@"%@ c%ld", command,
                                      (long)record.identifier];
            [suggestions addObject:[self suggestion:[self itemLabel:record] replacement:replacement]];
        }
    } else if ([command isEqualToString:@"help"]) {
        for (NSDictionary<NSString *, id> *entry in self.commands) {
            NSString *name = entry[@"name"];
            if (!argument.length || [name hasPrefix:argument.lowercaseString]) {
                [suggestions addObject:[self suggestion:
                    [NSString stringWithFormat:@"%@ — %@", name, entry[@"summary"]]
                    replacement:[NSString stringWithFormat:@"help %@", name]]];
                if (suggestions.count >= limit) break;
            }
        }
    }
    return suggestions.copy;
}

@end
