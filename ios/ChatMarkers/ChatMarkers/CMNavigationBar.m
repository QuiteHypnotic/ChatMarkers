//
//  CMNavigationBar.m
//  ChatMarkers
//
//  Created by James McEvoy on 7/29/13.
//  Copyright (c) 2013 Chat Markers LLC. All rights reserved.
//

#import "CMNavigationBar.h"

@implementation CMNavigationBar

- (void)awakeFromNib
{
    [super awakeFromNib];
    [self setBackgroundImage:[UIImage imageNamed:@"background_navigation"] forBarMetrics:UIBarMetricsDefault];
}

@end
