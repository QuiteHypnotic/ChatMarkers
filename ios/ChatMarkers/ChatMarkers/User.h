//
//  User.h
//  ChatMarkers
//
//  Created by James McEvoy on 7/27/13.
//  Copyright (c) 2013 Chat Markers LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Message, Thread;

@interface User : NSManagedObject

@property (nonatomic, retain) NSString * displayName;
@property (nonatomic, retain) NSString * remoteId;
@property (nonatomic, retain) NSSet *messages;
@property (nonatomic, retain) Thread *thread;
@property (nonatomic, retain) Thread *myThread;
@end

@interface User (CoreDataGeneratedAccessors)

- (void)addMessagesObject:(Message *)value;
- (void)removeMessagesObject:(Message *)value;
- (void)addMessages:(NSSet *)values;
- (void)removeMessages:(NSSet *)values;

@end
