//
//  CMAlertView.h
//  ChatMarkers
//
//  Created by James McEvoy on 7/26/13.
//  Copyright (c) 2013 Chat Markers LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CMAlertView : NSObject

+ (CMAlertView*)alertWithServerError:(NSError*)error reponse:(NSDictionary*)response;
+ (CMAlertView*)alertWithErrorMessage:(NSString*)message;
+ (CMAlertView*)alertWithTitle:(NSString*)title message:(NSString*)message;

- (void)addButton:(NSString*)title action:(void(^)(CMAlertView *view))action;
- (void)show;
- (void)dismiss;

@end
