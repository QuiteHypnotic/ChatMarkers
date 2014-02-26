//
//  ServerRequest.m
//  ChatMarkers
//
//  Created by James McEvoy on 7/30/13.
//  Copyright (c) 2013 Chat Markers LLC. All rights reserved.
//

#import "ServerRequest.h"

@interface ServerRequest()

@property(nonatomic,copy) void(^completionHandler)(NSURLResponse*,NSData*,NSError*);

@end

@implementation ServerRequest {
    NSMutableData *_data;
    NSURLResponse *_response;
}

- (id)initWithCompletionHandler:(void(^)(NSURLResponse*,NSData*,NSError*))completionHandler
{
    if (self = [super init]) {
        _data = [[NSMutableData alloc] init];
        self.completionHandler = completionHandler;
    }
    return self;
}

#pragma mark - NSURLConnectionDelegate

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse
{
    return cachedResponse;
}

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse
{
    return request;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    _response = response;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [_data appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    self.completionHandler(_response, _data, nil);
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    self.completionHandler(_response, _data, error);
}

@end
