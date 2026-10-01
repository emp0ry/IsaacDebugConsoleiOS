#import "IDCItemCatalog.h"
#import "IDCLogger.h"

@implementation IDCItemRecord
@end

@interface IDCItemCatalog () <NSXMLParserDelegate>
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, IDCItemRecord *> *recordsByID;
@property(nonatomic, copy) NSArray<IDCItemRecord *> *sortedRecords;
@end

@implementation IDCItemCatalog

- (instancetype)init {
    self = [super init];
    if (self) {
        _recordsByID = [NSMutableDictionary dictionary];
        [self loadCatalog];
    }
    return self;
}

- (NSUInteger)count {
    return self.sortedRecords.count;
}

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

- (NSString *)displayNameFromAttributes:(NSDictionary<NSString *, NSString *> *)attributes
                              identifier:(NSInteger)identifier {
    NSString *name = attributes[@"name"];
    if (name.length && ![name hasPrefix:@"#"]) return name;
    NSString *filename = [attributes[@"gfx"] lastPathComponent];
    NSString *stem = [filename stringByDeletingPathExtension];
    NSRegularExpression *prefix = [NSRegularExpression
        regularExpressionWithPattern:@"^Collectibles_[0-9]+_" options:0 error:nil];
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
        NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
        parser.delegate = self;
        [parser parse];
    }
    self.sortedRecords = [[self.recordsByID allValues]
        sortedArrayUsingComparator:^NSComparisonResult(IDCItemRecord *left, IDCItemRecord *right) {
        if (left.identifier < right.identifier) return NSOrderedAscending;
        if (left.identifier > right.identifier) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    IDCLog(@"item catalog loaded: %lu entries", (unsigned long)self.sortedRecords.count);
}

- (void)parser:(NSXMLParser *)parser
 didStartElement:(NSString *)elementName
    namespaceURI:(NSString *)namespaceURI
   qualifiedName:(NSString *)qualifiedName
      attributes:(NSDictionary<NSString *, NSString *> *)attributes {
    (void)parser; (void)namespaceURI; (void)qualifiedName;
    if (![@[@"passive", @"active", @"familiar"] containsObject:elementName]) return;
    NSInteger identifier = attributes[@"id"].integerValue;
    if (identifier < 1 || identifier > 732) return;
    IDCItemRecord *record = [IDCItemRecord new];
    record.identifier = identifier;
    record.name = [self displayNameFromAttributes:attributes identifier:identifier];
    record.kind = elementName;
    self.recordsByID[@(identifier)] = record;
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
    NSString *needle = [[query stringByTrimmingCharactersInSet:
        NSCharacterSet.whitespaceAndNewlineCharacterSet] lowercaseString];
    if ([needle hasPrefix:@"c"] && needle.length > 1) needle = [needle substringFromIndex:1];
    NSMutableArray<IDCItemRecord *> *prefixMatches = [NSMutableArray array];
    NSMutableArray<IDCItemRecord *> *containsMatches = [NSMutableArray array];
    for (IDCItemRecord *record in self.sortedRecords) {
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

@end
