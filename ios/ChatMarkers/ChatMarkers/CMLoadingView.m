//
//  CMLoadingView.m
//  ChatMarkers
//
//  Created by James McEvoy on 7/26/13.
//  Copyright (c) 2013 Chat Markers LLC. All rights reserved.
//

#import "CMLoadingView.h"

@implementation CMLoadingView

+ (CMLoadingView*)showInView:(UIView*)view message:(NSString*)message
{
    CMLoadingView *loadingView = [[CMLoadingView alloc] initWithFrame:view.bounds];
    loadingView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
    
    UIActivityIndicatorView *activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    activityView.center = CGPointMake(loadingView.frame.size.width / 2, loadingView.frame.size.height / 2);
    [loadingView addSubview:activityView];
    [activityView startAnimating];
    
    [view addSubview:loadingView];
    
    return loadingView;
}

- (void)dismiss
{
    [self removeFromSuperview];
}

@end
