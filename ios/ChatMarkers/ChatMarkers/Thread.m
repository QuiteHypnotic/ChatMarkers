//
//  Thread.m
//  ChatMarkers
//
//  Created by James McEvoy on 8/2/13.
//  Copyright (c) 2013 Chat Markers LLC. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>
#import "Constants.h"
#import "Thread.h"
#import "Message.h"
#import "User.h"


@implementation Thread

@dynamic expiration;
@dynamic latitude;
@dynamic longitude;
@dynamic name;
@dynamic details;
@dynamic remoteId;
@dynamic subscribed;
@dynamic time;
@dynamic unread;
@dynamic radius;
@dynamic password;
@dynamic distance;
@dynamic me;
@dynamic messages;
@dynamic users;

- (void)awakeFromFetch
{
    [super awakeFromFetch];
    [self calculateDistance];
}

- (void)awakeFromInsert
{
    [super awakeFromInsert];
    [self calculateDistance];
}

- (void)calculateDistance
{
    CLLocation *location = [[CLLocation alloc] initWithLatitude:self.latitude.doubleValue longitude:self.longitude.doubleValue];
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    self.distance = @([[[CLLocation alloc] initWithLatitude:[userDefaults doubleForKey:kUserDefaultsLatitude] longitude:[userDefaults doubleForKey:kUserDefaultsLongitude]] distanceFromLocation:location]);
}

@end
