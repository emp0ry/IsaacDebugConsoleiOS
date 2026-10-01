#import "IDCCommandEngine.h"
#import "IDCItemCatalog.h"
#import "IDCNativeBridge.h"

static NSString *const IDCVersion = @"0.2.0";

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
               @"summary": @"Show every command or detailed help" },
            @{ @"name": @"status", @"aliases": @[], @"usage": @"status",
               @"summary": @"Show native bridge, run, and catalog state" },
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
            @{ @"name": @"trinkets", @"aliases": @[], @"usage": @"trinkets [name|id]",
               @"summary": @"List or search trinkets" },
            @{ @"name": @"cards", @"aliases": @[], @"usage": @"cards [name|id]",
               @"summary": @"List or search cards" },
            @{ @"name": @"runes", @"aliases": @[], @"usage": @"runes [name|id]",
               @"summary": @"List or search runes and soul stones" },
            @{ @"name": @"pilleffects", @"aliases": @[@"pills"],
               @"usage": @"pilleffects [name|id]",
               @"summary": @"List or search pill effects" },
            @{ @"name": @"giveitem", @"aliases": @[@"g"],
               @"usage": @"giveitem <cID|name>",
               @"summary": @"Give a collectible directly to the player" },
            @{ @"name": @"remove", @"aliases": @[@"r"],
               @"usage": @"remove <cID|name>",
               @"summary": @"Remove one collectible from the player" },
            @{ @"name": @"spawn", @"aliases": @[@"s"],
               @"usage": @"spawn <type.variant.subtype>",
               @"summary": @"Spawn a native entity beside the player" },
            @{ @"name": @"spawnpickup", @"aliases": @[@"pickup"],
               @"usage": @"spawnpickup <variant.subtype>",
               @"summary": @"Spawn a pickup beside the player" },
            @{ @"name": @"spawnitem", @"aliases": @[@"si"],
               @"usage": @"spawnitem <cID|name>",
               @"summary": @"Spawn a collectible pedestal in the room" },
            @{ @"name": @"spawntrinket", @"aliases": @[@"st"],
               @"usage": @"spawntrinket <tID|name>",
               @"summary": @"Spawn a trinket in the room" },
            @{ @"name": @"spawncard", @"aliases": @[@"sc"],
               @"usage": @"spawncard <ID|name>",
               @"summary": @"Spawn a card in the room" },
            @{ @"name": @"spawnrune", @"aliases": @[@"sr", @"spawnrun"],
               @"usage": @"spawnrune <ID|1-10|name>",
               @"summary": @"Spawn a rune or soul stone in the room" },
            @{ @"name": @"spawnpill", @"aliases": @[@"sp"],
               @"usage": @"spawnpill <color|effect> [horse]",
               @"summary": @"Spawn a pill from this run's pill pool" },
            @{ @"name": @"rewind", @"aliases": @[@"hourglass"], @"usage": @"rewind",
               @"summary": @"Rewind through Isaac's Glowing Hourglass logic" },
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

- (NSString *)labelForRecord:(IDCItemRecord *)record prefix:(NSString *)prefix {
    return [NSString stringWithFormat:@"%@%ld — %@", prefix, (long)record.identifier,
                                      record.name];
}

- (BOOL)parseUnsignedComponents:(NSString *)argument
                          count:(NSUInteger)expectedCount
                         values:(NSArray<NSNumber *> * _Nullable * _Nullable)values {
    NSString *normalized = argument;
    for (NSString *separator in @[@".", @":", @","]) {
        normalized = [normalized stringByReplacingOccurrencesOfString:separator withString:@" "];
    }
    NSArray<NSString *> *raw = [normalized componentsSeparatedByCharactersInSet:
        NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSMutableArray<NSNumber *> *parsed = [NSMutableArray array];
    for (NSString *component in raw) {
        if (!component.length) continue;
        if ([component rangeOfCharacterFromSet:
                NSCharacterSet.decimalDigitCharacterSet.invertedSet].location != NSNotFound) {
            return NO;
        }
        [parsed addObject:@(component.integerValue)];
    }
    if (parsed.count != expectedCount) return NO;
    if (values) *values = parsed.copy;
    return YES;
}

- (NSArray<IDCItemRecord *> *)recordsForListCommand:(NSString *)command
                                               query:(NSString *)query
                                               limit:(NSUInteger)limit {
    if ([command isEqualToString:@"items"]) {
        return [self.catalog recordsMatching:query limit:limit];
    }
    if ([command isEqualToString:@"trinkets"]) {
        return [self.catalog trinketsMatching:query limit:limit];
    }
    if ([command isEqualToString:@"cards"] || [command isEqualToString:@"runes"]) {
        NSString *kind = [command isEqualToString:@"cards"] ? @"card" : @"rune";
        return [self.catalog pocketItemsMatching:query kind:kind limit:limit];
    }
    return [self.catalog pillEffectsMatching:query limit:limit];
}

- (NSString *)prefixForListCommand:(NSString *)command {
    if ([command isEqualToString:@"items"]) return @"c";
    if ([command isEqualToString:@"trinkets"]) return @"t";
    if ([command isEqualToString:@"cards"]) return @"card ";
    if ([command isEqualToString:@"runes"]) return @"rune ";
    return @"effect ";
}

- (IDCCommandResult *)nativeResultForError:(NSString *)error success:(NSString *)success {
    if (error) return [self result:[@"Error: " stringByAppendingString:error]
                              action:IDCCommandActionNone];
    return [self result:success action:IDCCommandActionNone];
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
                              entry[@"usage"], entry[@"summary"]]];
        }
        [lines addObject:@"Tap a suggestion to fill it. Native modifying commands require a paused run."];
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
            @"Bridge: %@\nUUID: %@\nState: %@\nCatalog: %lu items, %lu trinkets, %lu cards/runes, %lu pill effects",
            snapshot.supportedBuild ? @"supported" : @"disabled", snapshot.executableUUID,
            state, (unsigned long)self.catalog.count, (unsigned long)self.catalog.trinketCount,
            (unsigned long)self.catalog.pocketItemCount,
            (unsigned long)self.catalog.pillEffectCount] action:IDCCommandActionNone];
    }

    if ([@[@"items", @"trinkets", @"cards", @"runes", @"pilleffects"]
            containsObject:command]) {
        if ([command isEqualToString:@"items"] && !argument.length) {
            return [self result:@"Usage: items <name|id>" action:IDCCommandActionNone];
        }
        NSArray<IDCItemRecord *> *matches = [self recordsForListCommand:command
                                                                   query:argument limit:30];
        if (!matches.count) return [self result:@"No matching catalog entries."
                                               action:IDCCommandActionNone];
        NSString *prefix = [self prefixForListCommand:command];
        NSMutableArray<NSString *> *lines = [NSMutableArray array];
        for (IDCItemRecord *record in matches) {
            [lines addObject:[self labelForRecord:record prefix:prefix]];
        }
        return [self result:[lines componentsJoinedByString:@"\n"] action:IDCCommandActionNone];
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
    if ([command isEqualToString:@"giveitem"] || [command isEqualToString:@"remove"]) {
        NSString *lookupError = nil;
        IDCItemRecord *record = [self.catalog recordForSpecifier:argument error:&lookupError];
        if (!record) return [self result:lookupError action:IDCCommandActionNone];
        NSString *nativeError = [command isEqualToString:@"giveitem"]
            ? [self.bridge giveCollectible:record.identifier]
            : [self.bridge removeCollectible:record.identifier];
        NSString *verb = [command isEqualToString:@"giveitem"] ? @"Added" : @"Removed";
        return [self nativeResultForError:nativeError success:[NSString stringWithFormat:
            @"%@ c%ld — %@", verb, (long)record.identifier, record.name]];
    }
    if ([command isEqualToString:@"spawn"] || [command isEqualToString:@"spawnpickup"]) {
        NSUInteger componentCount = [command isEqualToString:@"spawn"] ? 3 : 2;
        NSArray<NSNumber *> *values = nil;
        if (![self parseUnsignedComponents:argument count:componentCount values:&values]) {
            return [self result:[NSString stringWithFormat:@"Usage: %@", definition[@"usage"]]
                             action:IDCCommandActionNone];
        }
        NSInteger type = [command isEqualToString:@"spawn"] ? values[0].integerValue : 5;
        NSInteger index = [command isEqualToString:@"spawn"] ? 1 : 0;
        NSInteger variant = values[(NSUInteger)index].integerValue;
        NSInteger subtype = values[(NSUInteger)index + 1].integerValue;
        NSString *error = [self.bridge spawnEntityType:type variant:variant subtype:subtype];
        return [self nativeResultForError:error success:[NSString stringWithFormat:
            @"Spawned %ld.%ld.%ld beside the player.", (long)type, (long)variant,
            (long)subtype]];
    }
    if ([command isEqualToString:@"spawnitem"]) {
        NSString *lookupError = nil;
        IDCItemRecord *record = [self.catalog recordForSpecifier:argument error:&lookupError];
        if (!record) return [self result:lookupError action:IDCCommandActionNone];
        NSString *error = [self.bridge spawnEntityType:5 variant:100 subtype:record.identifier];
        return [self nativeResultForError:error success:[NSString stringWithFormat:
            @"Spawned collectible c%ld — %@.", (long)record.identifier, record.name]];
    }
    if ([command isEqualToString:@"spawntrinket"]) {
        NSString *lookupError = nil;
        IDCItemRecord *record = [self.catalog trinketForSpecifier:argument error:&lookupError];
        if (!record) return [self result:lookupError action:IDCCommandActionNone];
        NSString *error = [self.bridge spawnEntityType:5 variant:350 subtype:record.identifier];
        return [self nativeResultForError:error success:[NSString stringWithFormat:
            @"Spawned trinket t%ld — %@.", (long)record.identifier, record.name]];
    }
    if ([command isEqualToString:@"spawncard"] || [command isEqualToString:@"spawnrune"]) {
        BOOL rune = [command isEqualToString:@"spawnrune"];
        NSString *specifier = argument;
        if (rune && argument.length &&
            [argument rangeOfCharacterFromSet:
                NSCharacterSet.decimalDigitCharacterSet.invertedSet].location == NSNotFound) {
            NSInteger shortID = argument.integerValue;
            if (shortID >= 1 && shortID <= 10) {
                specifier = [NSString stringWithFormat:@"%ld", (long)(shortID + 31)];
            }
        }
        NSString *lookupError = nil;
        IDCItemRecord *record = [self.catalog pocketItemForSpecifier:specifier
            kind:rune ? @"rune" : @"card" error:&lookupError];
        if (!record) return [self result:lookupError action:IDCCommandActionNone];
        NSString *error = [self.bridge spawnEntityType:5 variant:300 subtype:record.identifier];
        return [self nativeResultForError:error success:[NSString stringWithFormat:
            @"Spawned %@ %ld — %@.", rune ? @"rune" : @"card",
            (long)record.identifier, record.name]];
    }
    if ([command isEqualToString:@"spawnpill"]) {
        NSString *query = [argument stringByTrimmingCharactersInSet:
            NSCharacterSet.whitespaceAndNewlineCharacterSet];
        BOOL horse = NO;
        NSRange lastSpace = [query rangeOfCharacterFromSet:NSCharacterSet.whitespaceCharacterSet
                                                   options:NSBackwardsSearch];
        NSString *lastToken = lastSpace.location == NSNotFound ? query :
            [query substringFromIndex:NSMaxRange(lastSpace)];
        if ([lastToken.lowercaseString isEqualToString:@"horse"] ||
            [lastToken.lowercaseString isEqualToString:@"horsepill"]) {
            horse = YES;
            query = lastSpace.location == NSNotFound ? @"" : [[query substringToIndex:lastSpace.location]
                stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        }
        BOOL explicitEffect = [query.lowercaseString hasPrefix:@"effect "];
        if (explicitEffect) query = [[query substringFromIndex:7]
            stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        query = [query stringByReplacingOccurrencesOfString:@"\"" withString:@""];
        BOOL numeric = query.length && [query rangeOfCharacterFromSet:
            NSCharacterSet.decimalDigitCharacterSet.invertedSet].location == NSNotFound;
        if (numeric && !explicitEffect) {
            NSInteger color = query.integerValue;
            if (color < 1 || color > 14) {
                return [self result:@"Pill color must be between 1 and 14. Use ‘effect <id>’ for an effect ID."
                                 action:IDCCommandActionNone];
            }
            NSInteger subtype = color | (horse ? (1 << 11) : 0);
            NSString *error = [self.bridge spawnEntityType:5 variant:70 subtype:subtype];
            return [self nativeResultForError:error success:[NSString stringWithFormat:
                @"Spawned %@pill color %ld.", horse ? @"horse " : @"", (long)color]];
        }
        NSString *lookupError = nil;
        IDCItemRecord *effect = [self.catalog pillEffectForSpecifier:query error:&lookupError];
        if (!effect) return [self result:lookupError action:IDCCommandActionNone];
        NSInteger color = 0;
        NSString *error = [self.bridge spawnPillEffect:effect.identifier horse:horse
                                         resolvedColor:&color];
        return [self nativeResultForError:error success:[NSString stringWithFormat:
            @"Spawned %@pill color %ld — %@.", horse ? @"horse " : @"", (long)color,
            effect.name]];
    }
    if ([command isEqualToString:@"rewind"]) {
        NSString *error = [self.bridge rewind];
        return [self nativeResultForError:error
                                  success:@"Rewind triggered through Glowing Hourglass logic."];
    }
    return [self result:@"Command is not implemented." action:IDCCommandActionNone];
}

- (IDCCommandSuggestion *)suggestion:(NSString *)display replacement:(NSString *)replacement {
    IDCCommandSuggestion *suggestion = [IDCCommandSuggestion new];
    suggestion.displayText = display;
    suggestion.replacementText = replacement;
    return suggestion;
}

- (void)addRecordSuggestions:(NSArray<IDCItemRecord *> *)records
                      command:(NSString *)command
                       prefix:(NSString *)prefix
                           to:(NSMutableArray<IDCCommandSuggestion *> *)suggestions {
    for (IDCItemRecord *record in records) {
        [suggestions addObject:[self suggestion:[self labelForRecord:record prefix:prefix]
            replacement:[NSString stringWithFormat:@"%@ %ld", command, (long)record.identifier]]];
    }
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
        [command isEqualToString:@"items"] || [command isEqualToString:@"spawnitem"]) {
        for (IDCItemRecord *record in [self.catalog recordsMatching:argument limit:limit]) {
            NSString *replacement = [NSString stringWithFormat:@"%@ c%ld", command,
                                      (long)record.identifier];
            [suggestions addObject:[self suggestion:[self itemLabel:record] replacement:replacement]];
        }
    } else if ([command isEqualToString:@"trinkets"] ||
               [command isEqualToString:@"spawntrinket"]) {
        [self addRecordSuggestions:[self.catalog trinketsMatching:argument limit:limit]
                           command:command prefix:@"t" to:suggestions];
    } else if ([command isEqualToString:@"cards"] ||
               [command isEqualToString:@"spawncard"] ||
               [command isEqualToString:@"runes"] ||
               [command isEqualToString:@"spawnrune"]) {
        BOOL rune = [command isEqualToString:@"runes"] ||
            [command isEqualToString:@"spawnrune"];
        [self addRecordSuggestions:[self.catalog pocketItemsMatching:argument
                                     kind:rune ? @"rune" : @"card" limit:limit]
                           command:command prefix:rune ? @"rune " : @"card " to:suggestions];
    } else if ([command isEqualToString:@"pilleffects"] ||
               [command isEqualToString:@"spawnpill"]) {
        NSString *query = argument;
        if ([query.lowercaseString hasPrefix:@"effect "]) query = [query substringFromIndex:7];
        NSArray<IDCItemRecord *> *effects = [self.catalog pillEffectsMatching:query limit:limit];
        for (IDCItemRecord *record in effects) {
            NSString *replacement = [command isEqualToString:@"spawnpill"]
                ? [NSString stringWithFormat:@"spawnpill effect %ld", (long)record.identifier]
                : [NSString stringWithFormat:@"pilleffects %ld", (long)record.identifier];
            [suggestions addObject:[self suggestion:[self labelForRecord:record prefix:@"effect "]
                replacement:replacement]];
        }
        if ([command isEqualToString:@"spawnpill"] && !argument.length) {
            [suggestions insertObject:[self suggestion:@"spawnpill <color 1-14> [horse]"
                replacement:@"spawnpill 1"] atIndex:0];
        }
    } else if ([command isEqualToString:@"spawn"]) {
        [suggestions addObject:[self suggestion:@"type.variant.subtype (example: pickup collectible 1)"
            replacement:@"spawn 5.100.1"]];
    } else if ([command isEqualToString:@"spawnpickup"]) {
        [suggestions addObject:[self suggestion:@"variant.subtype (example: collectible 1)"
            replacement:@"spawnpickup 100.1"]];
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
    if (suggestions.count > limit) {
        [suggestions removeObjectsInRange:NSMakeRange(limit, suggestions.count - limit)];
    }
    return suggestions.copy;
}

@end
