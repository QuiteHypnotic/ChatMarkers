//
//  ServerRequest.h
//  ChatMarkers
//
//  Created by James McEvoy on 7/30/13.
//  Copyright (c) 2013 Chat Markers LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ServerRequest : NSObject <NSURLConnectionDelegate>

- (id)initWithCompletionHandler:(void(^)(NSURLResponse*,NSData*,NSError*))completionHandler;

@end
