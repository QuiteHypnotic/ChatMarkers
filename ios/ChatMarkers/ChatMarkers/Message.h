//
//  Message.h
//  ChatMarkers
//
//  Created by James McEvoy on 7/27/13.
//  Copyright (c) 2013 Chat Markers LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Thread, User;

@interface Message : NSManagedObject

@property (nonatomic, retain) NSString * text;
@property (nonatomic, retain) NSString * image;
@property (nonatomic, retain) NSString * time;
@property (nonatomic, retain) NSString * remoteId;
@property (nonatomic, retain) User *user;
@property (nonatomic, retain) Thread *thread;

@end
