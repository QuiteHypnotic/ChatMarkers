//
//  MarkerAnnotation.m
//  ChatMarkers
//
//  Created by James McEvoy on 7/28/13.
//  Copyright (c) 2013 Chat Markers LLC. All rights reserved.
//

#import "MarkerAnnotation.h"

@implementation MarkerAnnotation

- (id)initWithThread:(Thread*)thread
{
    if (self = [super init]) {
        _thread = thread;
    }
    return self;
}

- (NSString *)title
{
    if (_thread.password.boolValue) {
        return [@"\U0001f512 " stringByAppendingString:_thread.name];
    }
    return _thread.name;
}

- (NSString *)subtitle
{
    return _thread.details;
}

- (CLLocationCoordinate2D)coordinate
{
    return CLLocationCoordinate2DMake(_thread.latitude.doubleValue, _thread.longitude.doubleValue);
}

@end
