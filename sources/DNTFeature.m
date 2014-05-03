//
//  DNTFeature.m
//  DNTFeatures
//
//  Created by Daniel Thorpe on 25/04/2014.
//  Copyright (c) 2014 Daniel Thorpe. All rights reserved.
//

#import "DNTFeature.h"
#import "YapDatabase+DNTFeatures.h"

static YapDatabase *__database;
static NSString *__collection;

@interface DNTFeature ( /* Private */ )

@property (nonatomic, getter = isToggled, readwrite) BOOL toggled;

- (void)modify:(void(^)(DNTFeature *feature))modifications;

- (void)modify:(void(^)(DNTFeature *feature))modifications completion:(void(^)(void))completion inDatabase:(YapDatabase *)database collection:(NSString *)collection;

@end

@implementation DNTFeature

- (id)initWithKey:(id)key title:(NSString *)title group:(NSString *)group {
    self = [super init];
    if (self) {
        _key = key;
        _identifier = nil;
        _title = title;
        _parentFeatureKey = nil;
        _group = group;
        _groupOrder = @0;
        _userInfo = [NSMutableDictionary dictionary];

        _editable = YES;
        _onByDefault = NO;
        _on = NO;
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Feature: (%@) %@, %@, editable: %@, default: %@, currently: %@", self.group ?: @"none", self.title, self.key, DNT_YESNO(self.editable), DNT_YESNO(self.onByDefault), DNT_YESNO([self isOn])];
}

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeInteger:[DNTFeature version] forKey:DNT_STRING(VERSION)];
    [aCoder encodeObject:_key forKey:DNT_STRING(_key)];
    [aCoder encodeObject:_identifier forKey:DNT_STRING(_identifier)];
    [aCoder encodeObject:_title forKey:DNT_STRING(_title)];
    [aCoder encodeObject:_parentFeatureKey forKey:DNT_STRING(_parentFeatureKey)];
    [aCoder encodeObject:_group forKey:DNT_STRING(_group)];
    [aCoder encodeObject:_groupOrder forKey:DNT_STRING(_groupOrder)];
    [aCoder encodeBool:_editable forKey:DNT_STRING(_editable)];
    [aCoder encodeBool:_onByDefault forKey:DNT_STRING(_onByDefault)];
    [aCoder encodeBool:_on forKey:DNT_STRING(_on)];
    [aCoder encodeBool:_debugOptionsAvailable forKey:DNT_STRING(_debugOptionsAvailable)];
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    NSInteger version = [aDecoder decodeIntegerForKey:DNT_STRING(VERSION)];
    if ( [DNTFeature version] < version ) {
        return nil;
    }
    self = [super init];
    if (self) {
        _key = [aDecoder decodeObjectForKey:DNT_STRING(_key)];
        _identifier = [aDecoder decodeObjectForKey:DNT_STRING(_identifier)];
        _title = [aDecoder decodeObjectForKey:DNT_STRING(_title)];
        _parentFeatureKey = [aDecoder decodeObjectForKey:DNT_STRING(_parentFeatureKey)];
        _group = [aDecoder decodeObjectForKey:DNT_STRING(_group)];
        _groupOrder = [aDecoder decodeObjectForKey:DNT_STRING(_groupOrder)];
        _userInfo = [aDecoder decodeObjectForKey:DNT_STRING(_userInfo)] ?: [NSMutableDictionary dictionary];
        _editable = [aDecoder decodeBoolForKey:DNT_STRING(_editable)];
        _onByDefault = [aDecoder decodeBoolForKey:DNT_STRING(_onByDefault)];
        _on = [aDecoder decodeBoolForKey:DNT_STRING(_on)];
        _debugOptionsAvailable = [aDecoder decodeBoolForKey:DNT_STRING(_debugOptionsAvailable)];
    }
    return self;
}

#pragma mark - Dynamic Properties

- (BOOL)isToggled {
    return self.on != self.onByDefault;
}

#pragma mark - Public API

- (void)switchOnOrOff:(BOOL)onOrOff {
    [self modify:^(DNTFeature *feature) {
        feature->_on = onOrOff;
    }];
}

- (NSComparisonResult)compareWithOtherFeature:(DNTFeature *)feature {
    NSComparisonResult result = [self.identifier caseInsensitiveCompare:feature.identifier];
    if ( result == NSOrderedSame ) {
        result = [self.key caseInsensitiveCompare:feature.key];
    }
    return result;
}

- (void)updateFromExistingFeature:(DNTFeature *)feature {
    if ( [self.key isEqualToString:feature.key] ) {
        self.title = feature.title;
        self.group = feature.group;
        self.groupOrder = feature.groupOrder;
        self.identifier = feature.identifier;
        self.editable = feature.editable;
        self.onByDefault = feature.onByDefault;
        self->_on = feature.on;
    }
}

#pragma mark - Service

+ (NSArray *)features {
    return [self featuresInDatabase:[self database] collection:[self collection]];
}

+ (NSArray *)featuresInDatabase:(YapDatabase *)database collection:(NSString *)collection {
    __block NSMutableArray *features = [NSMutableArray array];
    YapDatabaseConnection *connection = [database newConnection];
    [connection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        [transaction enumerateKeysAndObjectsInCollection:collection usingBlock:^(NSString *key, id object, BOOL *stop) {
            if ( [object isKindOfClass:[DNTFeature class]] ) {
                [features addObject:object];
            }
        }];
    }];
    return features;
}

+ (instancetype)featureWithKey:(id)key {
    return [self featureWithKey:key inDatabase:[self database] collection:[self collection]];
}

+ (instancetype)featureWithKey:(id)key inDatabase:(YapDatabase *)database collection:(NSString *)collection {
    NSParameterAssert(key);
    __block DNTFeature *feature = nil;
    YapDatabaseConnection *connection = [database newConnection];
    [connection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        feature = [transaction objectForKey:key inCollection:collection];
    }];
    return feature;
}

+ (void)featureWithKey:(id)key update:(DNTFeatureBlock)update {
    [self featureWithKey:key update:update inDatabase:[self database] collection:[self collection]];
}

+ (void)featureWithKey:(id)key update:(DNTFeatureBlock)update inDatabase:(YapDatabase *)database collection:(NSString *)collection {
    NSParameterAssert(key);
    YapDatabaseConnection *connection = [database newConnection];
    __block DNTFeature *feature = nil;
    [connection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        feature = [self featureWithKey:key update:update collection:collection transaction:transaction];
    } completionBlock:^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DNTFeaturesDidChangeNotification object:nil userInfo:@{ DNTFeaturesNotificationFeatureKey : feature }];
    }];
}

+ (DNTFeature *)featureWithKey:(id)key update:(DNTFeatureBlock)update collection:(NSString *)collection transaction:(YapDatabaseReadWriteTransaction *)transaction {
    DNTFeature *existing = [transaction objectForKey:key inCollection:collection];
    DNTFeature *feature = update(existing, transaction);
    if (feature && existing) {
        feature->_on = feature.on || existing.on;
    }
    [transaction setObject:feature forKey:key inCollection:collection];
    return feature;
}

+ (void)switchFeatureWithKey:(id)key onOrOff:(BOOL)onOrOff {
    [self switchFeatureWithKey:key onOrOff:onOrOff inDatabase:[self database] collection:[self collection]];
}

+ (void)switchFeatureWithKey:(id)key onOrOff:(BOOL)onOrOff inDatabase:(YapDatabase *)database collection:(NSString *)collection {
    [self featureWithKey:key update:^(DNTFeature *feature, YapDatabaseReadWriteTransaction *transaction) {
        feature->_on = onOrOff;
        return feature;
    } inDatabase:database collection:collection];
}

+ (void)resetFeaturesToDefault {
    [self resetFeaturesToDefaultInDatabase:[self database] collection:[self collection]];
}

+ (void)resetFeaturesToDefaultInDatabase:(YapDatabase *)database collection:(NSString *)collection {
    YapDatabaseConnection *connection = [database newConnection];
    [connection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        NSMutableArray *requireSaving = [NSMutableArray array];
        [transaction enumerateKeysAndObjectsInCollection:collection usingBlock:^(NSString *key, id object, BOOL *stop) {
            if ( [object isKindOfClass:[DNTFeature class]] ) {
                DNTFeature *feature = (DNTFeature *)object;
                if ( feature.on != feature.onByDefault ) {
                    feature->_on = feature.onByDefault;
                    [requireSaving addObject:feature];
                }
            }
        }];
        for ( DNTFeature *feature in requireSaving ) {
            [transaction setObject:feature forKey:feature.key inCollection:collection];
        }
    }];
}

#pragma mark - Private API

- (void)modify:(void(^)(DNTFeature *feature))modifications {
    [self modify:modifications completion:nil inDatabase:[[self class] database] collection:[[self class] collection]];
}

- (void)modify:(void(^)(DNTFeature *feature))modifications completion:(void(^)(void))completion inDatabase:(YapDatabase *)database collection:(NSString *)collection {
    modifications(self);
    YapDatabaseConnection *connection = [database newConnection];
    DNT_WEAK_SELF
    [connection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        __strong DNTFeature *strongSelf = weakSelf;
        [transaction setObject:strongSelf forKey:strongSelf.key inCollection:collection];
    } completionBlock:^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DNTFeaturesDidChangeNotification object:self userInfo:@{ DNTFeaturesNotificationFeatureKey : self}];
        if (completion) completion();
    }];
}

#pragma mark - Persistence

+ (void)setDefaultDatabase:(YapDatabase *)database collection:(NSString *)collection {
    __database = database;
    __collection = collection;
}

+ (YapDatabase *)database {
    if ( !__database ) {
        __database = [[YapDatabase alloc] initWithPath:[YapDatabase pathForDatabaseWithName:@"Features"]];
    }
    return __database;
}

+ (NSString *)collection {
    if ( !__collection ) {
        __collection = @"features";
    }
    return __collection;
}

+ (NSInteger)version {
    return 1;
}

@end

#pragma mark - Constants
NSString * const DNTFeaturesDidChangeNotification = @"DNTFeaturesDidChangeNotificationName";
NSString * const DNTFeaturesNotificationFeatureKey = @"DNTFeaturesNotificationFeatureKey";
