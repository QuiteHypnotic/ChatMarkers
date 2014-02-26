//
//  Server.m
//  ChatMarkers
//
//  Created by James McEvoy on 7/26/13.
//  Copyright (c) 2013 Chat Markers LLC. All rights reserved.
//

#import <CommonCrypto/CommonDigest.h>
#import "AppDelegate.h"
#import "CMAlertView.h"
#import "KeychainItemWrapper.h"
#import "Message.h"
#import "NSManagedObjectContext+Utils.h"
#import "Server.h"
#import "ServerRequest.h"
#import "Thread.h"
#import "User.h"

@implementation Server {
    NSString *_baseURL;
    NSMutableDictionary *_fileDownloads;
    KeychainItemWrapper *_accessTokenKeychain;
    NSDateFormatter *_dateParserFormatter;
}

+ (Server*)sharedInstance {
    static dispatch_once_t once;
    static Server *instance = nil;
    dispatch_once(&once, ^{
        instance = [[super allocWithZone:nil] init];
    });
    return instance;
}

+ (id)allocWithZone:(NSZone *)zone {
    return [self sharedInstance];
}

- (id)init
{
    self = [super init];
    if (self) {
        _baseURL = @"http://chatmarkers.com/api/1";
        _fileDownloads = [[NSMutableDictionary alloc] init];
        _accessTokenKeychain = [[KeychainItemWrapper alloc] initWithIdentifier:@"Password" accessGroup:nil];
        
        _dateParserFormatter = [[NSDateFormatter alloc] init];
        [_dateParserFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSSZZZZ"];
    }
    return self;
}

- (BOOL)isAuthorized
{
    NSString *accessToken = [_accessTokenKeychain objectForKey:(__bridge id)kSecValueData];
    return accessToken.length > 0;
}

- (NSString*)accessToken
{
    return [_accessTokenKeychain objectForKey:(__bridge id)kSecValueData];
}

- (void)removeAccessToken
{
    [_accessTokenKeychain setObject:@"" forKey:(__bridge id)kSecValueData];
}

- (void)clearFileCache
{
    
}

- (NSURL*)pathToURL:(NSString*)path
{
    if ([self isAuthorized]) {
        path = [path stringByAppendingFormat:@"?token=%@", [self accessToken]];
    }
    return [NSURL URLWithString:[_baseURL stringByAppendingString:path]];
}

- (NSDate*)parseDate:(NSString*)date
{
    date = [date stringByReplacingOccurrencesOfString:@"Z" withString:@"GMT+00:00"];
    return [_dateParserFormatter dateFromString:date];
}

- (void)uploadFilePath:(NSString*)path params:(NSDictionary*)params filename:(NSString*)filename contentType:(NSString*)contentType data:(NSData*)data completionHandler:(void (^)(NSDictionary*, NSError*))completionHandler
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    [request setHTTPShouldHandleCookies:NO];
    [request setTimeoutInterval:30];
    [request setHTTPMethod:@"POST"];
    
    NSString *boundary = @"----------V2ymHFg03ehbqgZCaKO6jy";
    [request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary] forHTTPHeaderField: @"Content-Type"];
    
    NSMutableData *body = [NSMutableData data];
    
    for (NSString *param in params) {
        [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", param] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithFormat:@"%@\r\n", [params objectForKey:param]] dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n", filename, filename] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Type: %@\r\n\r\n", contentType] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:data];
    [body appendData:[[NSString stringWithFormat:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    
    [body appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [request setHTTPBody:body];
    
    NSString *postLength = [NSString stringWithFormat:@"%d", [body length]];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    
    [request setURL:[[Server sharedInstance] pathToURL:path]];
    
    [[Server sharedInstance] executeRequest:request completionHandler:completionHandler];
}

- (void)executeMethod:(NSString*)method path:(NSString*)path body:(id)body completionHandler:(void (^)(NSDictionary*, NSError*))completionHandler
{
    if ([self isAuthorized]) {
        if ([path rangeOfString:@"?"].location == NSNotFound) {
            path = [path stringByAppendingFormat:@"?token=%@", [self accessToken]];
        }
        else {
            path = [path stringByAppendingFormat:@"&token=%@", [self accessToken]];
        }
    }
    
    NSURL *url = [NSURL URLWithString:[_baseURL stringByAppendingString:path]];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    request.HTTPMethod = method;
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    if (body) {
        NSError *error = nil;
        request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:&error];
        if (error) {
            completionHandler(nil, error);
            return;
        }
    }
    [self executeRequest:request completionHandler:completionHandler];
}

- (void)executeRequest:(NSURLRequest*)request completionHandler:(void (^)(NSDictionary*, NSError*))completionHandler
{
    NSString *accessToken = @"";
    if ([self isAuthorized]) {
        accessToken = [self accessToken];
    }
    
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:[[ServerRequest alloc] initWithCompletionHandler:^(NSURLResponse *rawResponse, NSData *data, NSError *networkError) {
        dispatch_async(dispatch_get_main_queue(), ^() {
            if (![accessToken isEqualToString:[self accessToken]]) return;
            
            NSError *error = networkError;
            if (error) {
                completionHandler(nil, error);
            }
            else {
                NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                
                NSHTTPURLResponse *response = (NSHTTPURLResponse*)rawResponse;
                if (response.statusCode < 200 || response.statusCode >= 400) {
                    if ([self isAuthorized] && response.statusCode == 401) {
                        [[AppDelegate sharedInstance] logout];
                        [[CMAlertView alertWithTitle:@"Session expired!" message:@"Sorry, but your session has expired. Please log back in to access your account."] show];
                    }
                    else {
                        error = [NSError errorWithDomain:kAPIErrorDomain code:kHttpStatusCodeError userInfo:@{kHttpStatusCodeKey: @(response.statusCode)}];
                        completionHandler(result, error);
                    }
                }
                else {
                    NSString *accessToken = [result objectForKey:@"access_token"];
                    if (accessToken) {
                        [_accessTokenKeychain setObject:accessToken forKey:(__bridge id)kSecValueData];
                    }
                    completionHandler(result, error);
                }
            }
        });
    }]];
    [connection start];
}

- (void)downloadFileAtPath:(NSString*)path completionHandler:(void (^)(NSString*, NSError*))completionHandler
{
    NSString *accessToken = [_accessTokenKeychain objectForKey:(__bridge id)kSecValueData];
    if (accessToken) {
        path = [path stringByAppendingFormat:@"?token=%@", accessToken];
    }
    NSString *url = [_baseURL stringByAppendingString:path];
    [self downloadFileAtURL:url completionHandler:completionHandler];
}

- (void)downloadFileAtURL:(NSString*)url completionHandler:(void (^)(NSString*, NSError*))completionHandler
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *fileName = nil;
    
    {
        unsigned char hash[CC_SHA1_DIGEST_LENGTH];
        NSData *data = [url dataUsingEncoding:NSUTF8StringEncoding];
        if (CC_SHA1([data bytes], [data length], hash)) {
            NSData *sha1 = [NSData dataWithBytes:hash length:CC_SHA1_DIGEST_LENGTH];
            
            NSUInteger capacity = [sha1 length] * 2;
            NSMutableString *stringBuffer = [NSMutableString stringWithCapacity:capacity];
            const unsigned char *dataBuffer = [sha1 bytes];
            
            for (NSUInteger i = 0; i < [sha1 length]; ++i) {
                [stringBuffer appendFormat:@"%02X",(NSUInteger)dataBuffer[i]];
            }
            fileName = stringBuffer;
        }
    }
    
    NSString *mainCachePath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
    NSString *downloadCachePath = [mainCachePath stringByAppendingPathComponent:@"Downloads"];
    
    if (![fileManager fileExistsAtPath:downloadCachePath]) {
        [fileManager createDirectoryAtPath:downloadCachePath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    __block NSString *filePath = [downloadCachePath stringByAppendingPathComponent:fileName];
    
    @synchronized(self) {
        if ([fileManager fileExistsAtPath:filePath]) {
            completionHandler(filePath, nil);
            return;
        }
        
        NSMutableArray *callbacks = _fileDownloads[url];
        if (!callbacks) {
            callbacks = [[NSMutableArray alloc] init];
        }
        [callbacks addObject:[completionHandler copy]];
        _fileDownloads[url] = callbacks;
    }
    
    NSString *accessToken = @"";
    if ([self isAuthorized]) {
        accessToken = [self accessToken];
    }
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:url]];
    [NSURLConnection sendAsynchronousRequest:request queue:[[NSOperationQueue alloc] init] completionHandler:^(NSURLResponse *rawResponse, NSData *data, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^() {
            if (![accessToken isEqualToString:[self accessToken]]) return;
            
            @synchronized(self) {
                if (data.length) {
                    [data writeToFile:filePath atomically:YES];
                }
                else {
                    filePath = nil;
                }
                
                NSMutableArray *callbacks = _fileDownloads[url];
                for (void(^callback)(NSString*,NSError*) in callbacks) {
                    callback(filePath, error);
                }
                [_fileDownloads removeObjectForKey:url];
            }
        });
    }];
}

- (id)extractValue:(NSDictionary*)response key:(NSString*)key
{
    if (response[key] == [NSNull null]) {
        return nil;
    }
    return response[key];
}

- (void)downloadThreadsNearLocation:(CLLocation*)location completionHandler:(void (^)(NSArray*,NSError*))completionHandler
{
    NSString *path = [NSString stringWithFormat:@"/threads?latitude=%f&longitude=%f", location.coordinate.latitude, location.coordinate.longitude];

    [self executeMethod:@"GET" path:path body:nil completionHandler:^(NSDictionary *response, NSError *error) {
        if (error) {
            if (completionHandler) {
                completionHandler(nil, error);
            }
        }
        else {
            NSManagedObjectContext *managedObjectContext = [AppDelegate sharedInstance].managedObjectContext;
            NSMutableArray *threads = [[NSMutableArray alloc] init];
            
            for (NSDictionary *item in response[@"threads"]) {
                Thread *thread = [managedObjectContext upsertClass:[Thread class] column:@"remoteId" value:item[@"id"]];
                thread.name = item[@"name"];
                thread.details = [self extractValue:item key:@"details"];
                thread.radius = [self extractValue:item key:@"radius"];
                thread.latitude = [self extractValue:item key:@"latitude"];
                thread.longitude = [self extractValue:item key:@"longitude"];
                thread.subscribed = item[@"extra"][@"subscribed"];
                thread.password = item[@"password"];
                thread.unread = @(NO);
                [thread calculateDistance];
                [threads addObject:thread];
            }
            
            if (![managedObjectContext save:&error]) {
                NSLog(@"Unable to save thread users and messages: %@", error);
            }
            
            if (completionHandler) {
                completionHandler(threads, error);
            }
        }
    }];
}

- (void)downloadMessages:(Thread*)thread completionHandler:(void (^)(NSError*))completionHandler
{
    [self executeMethod:@"GET" path:[@"/threads/" stringByAppendingString:thread.remoteId] body:nil completionHandler:^(NSDictionary *response, NSError *error) {
        
        if (error) {
            if (completionHandler) {
                completionHandler(error);
            }
        }
        else {
            NSManagedObjectContext *managedObjectContext = thread.managedObjectContext;
            
            thread.name = response[@"name"];
            thread.details = [self extractValue:response key:@"details"];
            thread.radius = [self extractValue:response key:@"radius"];
            thread.latitude = [self extractValue:response key:@"latitude"];
            thread.longitude = [self extractValue:response key:@"longitude"];
            thread.subscribed = response[@"extra"][@"subscribed"];
            
            NSMutableDictionary *users = [[NSMutableDictionary alloc] init];
            for (NSDictionary *item in response[@"users"]) {
                User *user = [managedObjectContext upsertClass:[User class] column:@"remoteId" value:item[@"id"]];
                user.thread = thread;
                user.displayName = item[@"display_name"];
                users[user.remoteId] = user;
            }
            thread.me = users[response[@"extra"][@"uuid"]];
                    
            for (NSDictionary *item in response[@"messages"]) {
                Message *message = [managedObjectContext upsertClass:[Message class] column:@"remoteId" value:item[@"id"]];
                message.text = item[@"text"];
                message.image = item[@"image"];
                message.time = item[@"created_time"];
                message.user = users[item[@"user_id"]];
                if (!message.thread) {
                    thread.unread = @(YES);
                }
                message.thread = thread;
                
                if (!thread.time || [thread.time compare:message.time] == NSOrderedAscending) {
                    thread.time = message.time;
                }
            }
            
            if (![managedObjectContext save:&error]) {
                NSLog(@"Unable to save thread users and messages: %@", error);
            }
            
            if (completionHandler) {
                completionHandler(nil);
            }
        }
    }];
}

- (void)downloadThreadsWithCompletionHandler:(void (^)(NSError*))completionHandler
{
    [self executeMethod:@"GET" path:@"/users/me/threads" body:nil completionHandler:^(NSDictionary *response, NSError *error) {
        
        NSManagedObjectContext *managedObjectContext = [AppDelegate sharedInstance].managedObjectContext;
        
        if (error) {
            if (completionHandler) {
                completionHandler(error);
            }
        }
        else {
            __block NSError *messageError = nil;
            __block int count = [response[@"threads"] count];
            
            for (NSDictionary *item in response[@"threads"]) {
                Thread *thread = [managedObjectContext upsertClass:[Thread class] column:@"remoteId" value:item[@"id"]];
                thread.name = item[@"name"];
                if (!thread.unread) {
                    thread.unread = @(NO);
                }
                [self downloadMessages:thread completionHandler:^(NSError *error) {
                    count--;
                    if (error) {
                        messageError = error;
                    }
                    if (count == 0) {
                        if (completionHandler) {
                            completionHandler(messageError);
                        }
                    }
                }];
            }
        }
    }];
}

- (void)subscribeThread:(Thread*)thread password:(NSString*)password completionHandler:(void (^)(NSError*))completionHandler
{
    NSDictionary *params = nil;
    if (password) {
        params = @{@"password": password};
    }
    
    NSString *path = [NSString stringWithFormat:@"/users/me/threads/%@", thread.remoteId];
    [self executeMethod:@"PUT" path:path body:params completionHandler:^(NSDictionary *response, NSError *error) {
        if (error) {
            if (completionHandler) {
                completionHandler(error);
            }
        }
        else {
            [self downloadMessages:thread completionHandler:completionHandler];
        }
    }];
}

@end
