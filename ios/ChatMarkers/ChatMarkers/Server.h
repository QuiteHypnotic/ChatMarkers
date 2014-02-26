//
//  Server.h
//  ChatMarkers
//
//  Created by James McEvoy on 7/26/13.
//  Copyright (c) 2013 Chat Markers LLC. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#import "Thread.h"

#define kAPIErrorDomain @"com.chatmarkers.API_ERROR"
#define kHttpStatusCodeError 1
#define kHttpStatusCodeKey @"com.chatmarkers.STATUS_CODE"

@interface Server : NSObject

+ (Server*)sharedInstance;

- (BOOL)isAuthorized;
- (void)removeAccessToken;
- (void)clearFileCache;
- (NSURL*)pathToURL:(NSString*)path;
- (NSDate*)parseDate:(NSString*)date;

- (void)executeMethod:(NSString*)method path:(NSString*)path body:(id)body completionHandler:(void (^)(NSDictionary*, NSError*))completionHandler;
- (void)executeRequest:(NSURLRequest*)request completionHandler:(void (^)(NSDictionary*, NSError*))completionHandler;

- (void)downloadFileAtPath:(NSString*)path completionHandler:(void (^)(NSString*, NSError*))completionHandler;
- (void)downloadFileAtURL:(NSString*)url completionHandler:(void (^)(NSString*, NSError*))completionHandler;

- (void)uploadFilePath:(NSString*)path params:(NSDictionary*)params filename:(NSString*)filename contentType:(NSString*)contentType data:(NSData*)data completionHandler:(void (^)(NSDictionary*, NSError*))completionHandler;

- (void)downloadMessages:(Thread*)thread completionHandler:(void (^)(NSError*))completionHandler;
- (void)downloadThreadsWithCompletionHandler:(void (^)(NSError*))completionHandler;
- (void)subscribeThread:(Thread*)thread password:(NSString*)password completionHandler:(void (^)(NSError*))completionHandler;
- (void)downloadThreadsNearLocation:(CLLocation*)location completionHandler:(void (^)(NSArray*,NSError*))completionHandler;

@end
