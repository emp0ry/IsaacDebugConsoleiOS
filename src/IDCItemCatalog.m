#import "IDCItemCatalog.h"
#import "IDCLogger.h"

@implementation IDCItemRecord
@end

@interface IDCItemCatalog () <NSXMLParserDelegate>
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, IDCItemRecord *> *recordsByID;
@property(nonatomic, copy) NSArray<IDCItemRecord *> *sortedRecords;
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, IDCItemRecord *> *trinketsByID;
@property(nonatomic, copy) NSArray<IDCItemRecord *> *sortedTrinkets;
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, IDCItemRecord *> *pocketItemsByID;
@property(nonatomic, copy) NSArray<IDCItemRecord *> *sortedPocketItems;
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, IDCItemRecord *> *pillEffectsByID;
@property(nonatomic, copy) NSArray<IDCItemRecord *> *sortedPillEffects;
@property(nonatomic) BOOL parsingPocketItems;
@end

@implementation IDCItemCatalog

- (instancetype)init {
    self = [super init];
    if (self) {
        _recordsByID = [NSMutableDictionary dictionary];
        _trinketsByID = [NSMutableDictionary dictionary];
        _pocketItemsByID = [NSMutableDictionary dictionary];
        _pillEffectsByID = [NSMutableDictionary dictionary];
        [self loadCatalog];
    }
    return self;
}

- (NSUInteger)count {
    return self.sortedRecords.count;
}

- (NSUInteger)trinketCount { return self.sortedTrinkets.count; }
- (NSUInteger)pocketItemCount { return self.sortedPocketItems.count; }
- (NSUInteger)pillEffectCount { return self.sortedPillEffects.count; }

- (NSString *)itemsXMLPath {
    NSArray<NSString *> *roots = @[@"repentance-resources", @"afterbirthplus-resources",
                                    @"afterbirth-resources", @"rebirth-resources"];
    for (NSString *root in roots) {
        NSString *path = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:
            [NSString stringWithFormat:@"%@/data/items.xml", root]];
        if ([[NSFileManager defaultManager] isReadableFileAtPath:path]) return path;
    }
    return nil;
}

- (NSString *)pocketItemsXMLPath {
    NSArray<NSString *> *roots = @[@"repentance-resources", @"afterbirthplus-resources",
                                    @"afterbirth-resources", @"rebirth-resources"];
    for (NSString *root in roots) {
        NSString *path = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:
            [NSString stringWithFormat:@"%@/data/pocketitems.xml", root]];
        if ([[NSFileManager defaultManager] isReadableFileAtPath:path]) return path;
    }
    return nil;
}

- (NSString *)displayNameFromLocalizationKey:(NSString *)key fallback:(NSString *)fallback {
    if (!key.length || ![key hasPrefix:@"#"]) return key.length ? key : fallback;
    NSString *name = [key substringFromIndex:1];
    if ([name hasSuffix:@"_NAME"]) name = [name substringToIndex:name.length - 5];
    name = [name stringByReplacingOccurrencesOfString:@"_" withString:@" "];
    return name.capitalizedString.length ? name.capitalizedString : fallback;
}

- (NSString *)displayNameFromAttributes:(NSDictionary<NSString *, NSString *> *)attributes
                              identifier:(NSInteger)identifier {
    NSString *name = attributes[@"name"];
    if (name.length && ![name hasPrefix:@"#"]) return name;
    NSString *filename = [attributes[@"gfx"] lastPathComponent];
    NSString *stem = [filename stringByDeletingPathExtension];
    NSRegularExpression *prefix = [NSRegularExpression
        regularExpressionWithPattern:@"^(Collectibles|Trinkets)_[0-9]+_"
                              options:NSRegularExpressionCaseInsensitive error:nil];
    stem = [prefix stringByReplacingMatchesInString:stem ?: @""
                                            options:0 range:NSMakeRange(0, stem.length)
                                      withTemplate:@""];
    if (!stem.length) return [NSString stringWithFormat:@"Collectible %ld", (long)identifier];
    NSMutableString *result = [NSMutableString string];
    NSCharacterSet *uppercase = NSCharacterSet.uppercaseLetterCharacterSet;
    NSCharacterSet *lowercase = NSCharacterSet.lowercaseLetterCharacterSet;
    for (NSUInteger index = 0; index < stem.length; ++index) {
        unichar character = [stem characterAtIndex:index];
        if (index > 0 && [uppercase characterIsMember:character]) {
            unichar previous = [stem characterAtIndex:index - 1];
            if ([lowercase characterIsMember:previous]) [result appendString:@" "];
        }
        [result appendFormat:@"%C", character];
    }
    return result;
}

- (void)loadCatalog {
    NSString *path = [self itemsXMLPath];
    NSData *data = path.length ? [NSData dataWithContentsOfFile:path] : nil;
    if (data.length) {
        self.parsingPocketItems = NO;
        NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
        parser.delegate = self;
        [parser parse];
    }
    NSString *pocketPath = [self pocketItemsXMLPath];
    NSData *pocketData = pocketPath.length ? [NSData dataWithContentsOfFile:pocketPath] : nil;
    if (pocketData.length) {
        self.parsingPocketItems = YES;
        NSXMLParser *parser = [[NSXMLParser alloc] initWithData:pocketData];
        parser.delegate = self;
        [parser parse];
    }
    NSComparator byIdentifier = ^NSComparisonResult(IDCItemRecord *left, IDCItemRecord *right) {
        if (left.identifier < right.identifier) return NSOrderedAscending;
        if (left.identifier > right.identifier) return NSOrderedDescending;
        return NSOrderedSame;
    };
    self.sortedRecords = [[self.recordsByID allValues] sortedArrayUsingComparator:byIdentifier];
    self.sortedTrinkets = [[self.trinketsByID allValues] sortedArrayUsingComparator:byIdentifier];
    self.sortedPocketItems = [[self.pocketItemsByID allValues]
        sortedArrayUsingComparator:byIdentifier];
    self.sortedPillEffects = [[self.pillEffectsByID allValues]
        sortedArrayUsingComparator:byIdentifier];
    IDCLog(@"catalog loaded: %lu collectibles, %lu trinkets, %lu cards/runes, %lu pill effects",
           (unsigned long)self.sortedRecords.count, (unsigned long)self.sortedTrinkets.count,
           (unsigned long)self.sortedPocketItems.count,
           (unsigned long)self.sortedPillEffects.count);
}

- (void)parser:(NSXMLParser *)parser
 didStartElement:(NSString *)elementName
    namespaceURI:(NSString *)namespaceURI
   qualifiedName:(NSString *)qualifiedName
      attributes:(NSDictionary<NSString *, NSString *> *)attributes {
    (void)parser; (void)namespaceURI; (void)qualifiedName;
    if (self.parsingPocketItems) {
        if (![@[@"card", @"rune", @"pilleffect"] containsObject:elementName]) return;
        NSInteger identifier = attributes[@"id"].integerValue;
        NSInteger maximum = [elementName isEqualToString:@"pilleffect"] ? 49 : 97;
        if (identifier < ([elementName isEqualToString:@"pilleffect"] ? 0 : 1) ||
            identifier > maximum) return;
        IDCItemRecord *record = [IDCItemRecord new];
        record.identifier = identifier;
        NSString *fallback = [NSString stringWithFormat:@"%@ %ld",
            [elementName isEqualToString:@"pilleffect"] ? @"Pill effect" : @"Pocket item",
            (long)identifier];
        record.name = [self displayNameFromLocalizationKey:attributes[@"name"] fallback:fallback];
        BOOL rune = [elementName isEqualToString:@"rune"] ||
            [attributes[@"type"] isEqualToString:@"rune"];
        record.kind = [elementName isEqualToString:@"pilleffect"]
            ? @"pill" : (rune ? @"rune" : @"card");
        if ([elementName isEqualToString:@"pilleffect"]) {
            self.pillEffectsByID[@(identifier)] = record;
        } else {
            self.pocketItemsByID[@(identifier)] = record;
        }
        return;
    }
    if (![@[@"passive", @"active", @"familiar", @"trinket"]
            containsObject:elementName]) return;
    NSInteger identifier = attributes[@"id"].integerValue;
    NSInteger maximum = [elementName isEqualToString:@"trinket"] ? 190 : 732;
    if (identifier < 1 || identifier > maximum) return;
    IDCItemRecord *record = [IDCItemRecord new];
    record.identifier = identifier;
    record.name = [self displayNameFromAttributes:attributes identifier:identifier];
    record.kind = elementName;
    if ([elementName isEqualToString:@"trinket"]) {
        self.trinketsByID[@(identifier)] = record;
    } else {
        self.recordsByID[@(identifier)] = record;
    }
}

- (IDCItemRecord *)recordForIdentifier:(NSInteger)identifier {
    return self.recordsByID[@(identifier)];
}

- (IDCItemRecord *)recordForSpecifier:(NSString *)specifier error:(NSString **)error {
    NSString *trimmed = [specifier stringByTrimmingCharactersInSet:
        NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!trimmed.length) {
        if (error) *error = @"Missing collectible ID or name.";
        return nil;
    }
    NSString *numeric = trimmed;
    if ([[numeric lowercaseString] hasPrefix:@"c"] && numeric.length > 1) {
        numeric = [numeric substringFromIndex:1];
    }
    NSCharacterSet *nonDigits = NSCharacterSet.decimalDigitCharacterSet.invertedSet;
    if ([numeric rangeOfCharacterFromSet:nonDigits].location != NSNotFound) {
        // Continue with name matching.
    } else if (numeric.length) {
        NSInteger identifier = numeric.integerValue;
        if (identifier >= 1 && identifier <= 732) {
            IDCItemRecord *known = [self recordForIdentifier:identifier];
            if (known) return known;
            IDCItemRecord *fallback = [IDCItemRecord new];
            fallback.identifier = identifier;
            fallback.name = [NSString stringWithFormat:@"Collectible %ld", (long)identifier];
            fallback.kind = @"unknown";
            return fallback;
        }
        if (error) *error = @"Collectible ID must be between 1 and 732.";
        return nil;
    }

    NSString *query = trimmed.lowercaseString;
    NSArray<IDCItemRecord *> *exact = [self.sortedRecords filteredArrayUsingPredicate:
        [NSPredicate predicateWithBlock:^BOOL(IDCItemRecord *record, NSDictionary *bindings) {
        (void)bindings;
        return [record.name.lowercaseString isEqualToString:query];
    }]];
    if (exact.count == 1) return exact.firstObject;
    NSArray<IDCItemRecord *> *matches = [self recordsMatching:query limit:3];
    if (matches.count == 1) return matches.firstObject;
    if (error) {
        if (!matches.count) {
            *error = [NSString stringWithFormat:@"No collectible matches ‘%@’.", trimmed];
        } else {
            NSMutableArray<NSString *> *names = [NSMutableArray array];
            for (IDCItemRecord *record in matches) {
                [names addObject:[NSString stringWithFormat:@"c%ld %@",
                                  (long)record.identifier, record.name]];
            }
            *error = [NSString stringWithFormat:@"Ambiguous item: %@",
                      [names componentsJoinedByString:@", "]];
        }
    }
    return nil;
}

- (NSArray<IDCItemRecord *> *)recordsMatching:(NSString *)query limit:(NSUInteger)limit {
    return [self recordsMatching:query records:self.sortedRecords kind:nil limit:limit];
}

- (NSArray<IDCItemRecord *> *)recordsMatching:(NSString *)query
                                       records:(NSArray<IDCItemRecord *> *)records
                                          kind:(NSString *)kind
                                         limit:(NSUInteger)limit {
    NSString *needle = [[query stringByTrimmingCharactersInSet:
        NSCharacterSet.whitespaceAndNewlineCharacterSet] lowercaseString];
    if (needle.length > 1) {
        NSString *candidate = [needle substringFromIndex:1];
        if ([NSCharacterSet.letterCharacterSet characterIsMember:[needle characterAtIndex:0]] &&
            [candidate rangeOfCharacterFromSet:
                NSCharacterSet.decimalDigitCharacterSet.invertedSet].location == NSNotFound) {
            needle = candidate;
        }
    }
    NSMutableArray<IDCItemRecord *> *prefixMatches = [NSMutableArray array];
    NSMutableArray<IDCItemRecord *> *containsMatches = [NSMutableArray array];
    for (IDCItemRecord *record in records) {
        if (kind.length && ![record.kind isEqualToString:kind]) continue;
        NSString *identifier = [NSString stringWithFormat:@"%ld", (long)record.identifier];
        NSString *name = record.name.lowercaseString;
        if (!needle.length || [identifier hasPrefix:needle] || [name hasPrefix:needle]) {
            [prefixMatches addObject:record];
        } else if ([name containsString:needle]) {
            [containsMatches addObject:record];
        }
        if (prefixMatches.count >= limit) break;
    }
    if (prefixMatches.count < limit) {
        for (IDCItemRecord *record in containsMatches) {
            [prefixMatches addObject:record];
            if (prefixMatches.count >= limit) break;
        }
    }
    return prefixMatches.copy;
}

- (IDCItemRecord *)recordForSpecifier:(NSString *)specifier
                               records:(NSArray<IDCItemRecord *> *)records
                                  kind:(NSString *)kind
                             minimumID:(NSInteger)minimumID
                             maximumID:(NSInteger)maximumID
                                 label:(NSString *)label
                                 error:(NSString **)error {
    NSString *trimmed = [specifier stringByTrimmingCharactersInSet:
        NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!trimmed.length) {
        if (error) *error = [NSString stringWithFormat:@"Missing %@ ID or name.", label];
        return nil;
    }
    NSString *numeric = trimmed;
    if (numeric.length > 1 &&
        [NSCharacterSet.letterCharacterSet characterIsMember:[numeric characterAtIndex:0]]) {
        NSString *candidate = [numeric substringFromIndex:1];
        if ([candidate rangeOfCharacterFromSet:NSCharacterSet.decimalDigitCharacterSet.invertedSet]
                .location == NSNotFound) numeric = candidate;
    }
    if ([numeric rangeOfCharacterFromSet:NSCharacterSet.decimalDigitCharacterSet.invertedSet]
            .location == NSNotFound && numeric.length) {
        NSInteger identifier = numeric.integerValue;
        if (identifier < minimumID || identifier > maximumID) {
            if (error) *error = [NSString stringWithFormat:@"%@ ID must be between %ld and %ld.",
                label.capitalizedString, (long)minimumID, (long)maximumID];
            return nil;
        }
        for (IDCItemRecord *record in records) {
            if (record.identifier == identifier &&
                (!kind.length || [record.kind isEqualToString:kind])) return record;
        }
        if (error) *error = [NSString stringWithFormat:@"Unknown %@ ID %ld.",
            label, (long)identifier];
        return nil;
    }
    NSArray<IDCItemRecord *> *matches = [self recordsMatching:trimmed records:records
                                                          kind:kind limit:4];
    NSArray<IDCItemRecord *> *exact = [matches filteredArrayUsingPredicate:
        [NSPredicate predicateWithBlock:^BOOL(IDCItemRecord *record, NSDictionary *bindings) {
        (void)bindings;
        return [record.name.lowercaseString isEqualToString:trimmed.lowercaseString];
    }]];
    if (exact.count == 1) return exact.firstObject;
    if (matches.count == 1) return matches.firstObject;
    if (error) {
        if (!matches.count) {
            *error = [NSString stringWithFormat:@"No %@ matches ‘%@’.", label, trimmed];
        } else {
            NSMutableArray<NSString *> *values = [NSMutableArray array];
            for (IDCItemRecord *record in matches) {
                [values addObject:[NSString stringWithFormat:@"%ld %@",
                    (long)record.identifier, record.name]];
            }
            *error = [NSString stringWithFormat:@"Ambiguous %@: %@", label,
                [values componentsJoinedByString:@", "]];
        }
    }
    return nil;
}

- (IDCItemRecord *)trinketForSpecifier:(NSString *)specifier error:(NSString **)error {
    return [self recordForSpecifier:specifier records:self.sortedTrinkets kind:nil
                          minimumID:1 maximumID:190 label:@"trinket" error:error];
}

- (NSArray<IDCItemRecord *> *)trinketsMatching:(NSString *)query limit:(NSUInteger)limit {
    return [self recordsMatching:query records:self.sortedTrinkets kind:nil limit:limit];
}

- (IDCItemRecord *)pocketItemForSpecifier:(NSString *)specifier
                                      kind:(NSString *)kind
                                     error:(NSString **)error {
    return [self recordForSpecifier:specifier records:self.sortedPocketItems kind:kind
                          minimumID:1 maximumID:97 label:kind ?: @"card/rune" error:error];
}

- (NSArray<IDCItemRecord *> *)pocketItemsMatching:(NSString *)query
                                              kind:(NSString *)kind
                                             limit:(NSUInteger)limit {
    return [self recordsMatching:query records:self.sortedPocketItems kind:kind limit:limit];
}

- (IDCItemRecord *)pillEffectForSpecifier:(NSString *)specifier error:(NSString **)error {
    return [self recordForSpecifier:specifier records:self.sortedPillEffects kind:nil
                          minimumID:0 maximumID:49 label:@"pill effect" error:error];
}

- (NSArray<IDCItemRecord *> *)pillEffectsMatching:(NSString *)query limit:(NSUInteger)limit {
    return [self recordsMatching:query records:self.sortedPillEffects kind:nil limit:limit];
}

@end
