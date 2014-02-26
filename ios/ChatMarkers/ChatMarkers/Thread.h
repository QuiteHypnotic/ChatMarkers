//
//  Thread.h
//  ChatMarkers
//
//  Created by James McEvoy on 8/2/13.
//  Copyright (c) 2013 Chat Markers LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Message, User;

@interface Thread : NSManagedObject

@property (nonatomic, retain) NSDate * expiration;
@property (nonatomic, retain) NSNumber * latitude;
@property (nonatomic, retain) NSNumber * longitude;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSString * details;
@property (nonatomic, retain) NSString * remoteId;
@property (nonatomic, retain) NSNumber * subscribed;
@property (nonatomic, retain) NSString * time;
@property (nonatomic, retain) NSNumber * unread;
@property (nonatomic, retain) NSNumber * radius;
@property (nonatomic, retain) NSNumber * password;
@property (nonatomic, retain) NSNumber * distance;
@property (nonatomic, retain) User *me;
@property (nonatomic, retain) NSSet *messages;
@property (nonatomic, retain) NSSet *users;
@end

@interface Thread (CoreDataGeneratedAccessors)

- (void)addMessagesObject:(Message *)value;
- (void)removeMessagesObject:(Message *)value;
- (void)addMessages:(NSSet *)values;
- (void)removeMessages:(NSSet *)values;

- (void)addUsersObject:(User *)value;
- (void)removeUsersObject:(User *)value;
- (void)addUsers:(NSSet *)values;
- (void)removeUsers:(NSSet *)values;

- (void)calculateDistance;

@end
