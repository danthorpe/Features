//
//  DNTFeature.h
//  DNTFeatures
//
//  Created by Daniel Thorpe on 25/04/2014.
//  Copyright (c) 2014 Daniel Thorpe. All rights reserved.
//

#import <Foundation/Foundation.h>

@class YapDatabase, YapDatabaseReadWriteTransaction;
@class DNTFeature;

typedef DNTFeature *(^DNTFeatureBlock)(DNTFeature *feature, YapDatabaseReadWriteTransaction *transaction);

@interface DNTFeature : NSObject <NSCoding>

@property (nonatomic, strong) id key;
@property (nonatomic, strong) NSString *identifier;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *parentFeatureKey;

@property (nonatomic, strong) NSString *group;
@property (nonatomic, strong) NSNumber *groupOrder;
@property (nonatomic, getter = hasDebugOptions) BOOL debugOptionsAvailable;

@property (nonatomic, strong) NSMutableDictionary *userInfo; // Not persisted

@property (nonatomic, getter = isEditable) BOOL editable;
@property (nonatomic, getter = isOnByDefault) BOOL onByDefault;
@property (nonatomic, getter = isToggled, readonly) BOOL toggled;
@property (nonatomic, getter = isOn, readonly) BOOL on;

- (id)initWithKey:(id)key title:(NSString *)title group:(NSString *)group;

- (void)switchOnOrOff:(BOOL)onOrOff;

- (NSComparisonResult)compareWithOtherFeature:(DNTFeature *)feature;

- (void)updateFromExistingFeature:(DNTFeature *)feature;

/// @name Persisted Access

+ (NSArray *)features;
+ (NSArray *)featuresInDatabase:(YapDatabase *)database collection:(NSString *)collection;

+ (instancetype)featureWithKey:(id)key;
+ (instancetype)featureWithKey:(id)key inDatabase:(YapDatabase *)database collection:(NSString *)collection;

+ (void)featureWithKey:(id)key update:(DNTFeatureBlock)update;
+ (void)featureWithKey:(id)key update:(DNTFeatureBlock)update inDatabase:(YapDatabase *)database collection:(NSString *)collection;
+ (DNTFeature *)featureWithKey:(id)key update:(DNTFeatureBlock)update collection:(NSString *)collection transaction:(YapDatabaseReadWriteTransaction *)transaction;

+ (void)switchFeatureWithKey:(id)key onOrOff:(BOOL)onOrOff;
+ (void)switchFeatureWithKey:(id)key onOrOff:(BOOL)onOrOff inDatabase:(YapDatabase *)database collection:(NSString *)collection;

+ (void)resetFeaturesToDefault;
+ (void)resetFeaturesToDefaultInDatabase:(YapDatabase *)database collection:(NSString *)collection;

+ (void)setDefaultDatabase:(YapDatabase *)database collection:(NSString *)collection;
+ (YapDatabase *)database;
+ (NSString *)collection;
+ (NSInteger)version;

@end

/// @name Constants
extern NSString * const DNTFeaturesDidChangeNotification;
extern NSString * const DNTFeaturesNotificationFeatureKey;