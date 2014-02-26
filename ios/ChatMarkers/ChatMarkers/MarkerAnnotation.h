//
//  MarkerAnnotation.h
//  ChatMarkers
//
//  Created by James McEvoy on 7/28/13.
//  Copyright (c) 2013 Chat Markers LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>
#import "Thread.h"

@interface MarkerAnnotation : NSObject <MKAnnotation>

@property(nonatomic,strong,readonly) Thread *thread;

- (id)initWithThread:(Thread*)thread;

@end
