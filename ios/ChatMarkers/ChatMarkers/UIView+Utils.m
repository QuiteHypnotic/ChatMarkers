//
//  UIView+Utils.m
//  ChatMarkers
//
//  Created by James McEvoy on 7/28/13.
//  Copyright (c) 2013 Chat Markers LLC. All rights reserved.
//

#import "UIView+Utils.h"

@implementation UIView (Utils)

- (UIView*)findFirstResponder
{
    return [self findFirstSubview:^(UIView *view) {
        return view.isFirstResponder;
    }];
}

- (UIView*)findFirstSubview:(BOOL(^)(UIView*))matcher
{
    if (matcher(self)) {
        return self;
    }
    for (UIView *subview in self.subviews) {
        UIView *match = [subview findFirstSubview:matcher];
        if (match) return match;
    }
    return nil;
}

@end
