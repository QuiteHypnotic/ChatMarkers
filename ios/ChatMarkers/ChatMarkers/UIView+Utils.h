//
//  UIView+Utils.h
//  ChatMarkers
//
//  Created by James McEvoy on 7/28/13.
//  Copyright (c) 2013 Chat Markers LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIView (Utils)

- (UIView*)findFirstResponder;
- (UIView*)findFirstSubview:(BOOL(^)(UIView*))matcher;

@end
