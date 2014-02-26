//
//  CMButton.m
//  ChatMarkers
//
//  Created by James McEvoy on 7/25/13.
//  Copyright (c) 2013 Chat Markers LLC. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "CMButton.h"
#import "UIColor+Theme.h"

@implementation CMButton

- (id)init
{
    if (self = [super init]) {
        [self initialize];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        [self initialize];
    }
    return self;
}

- (void)awakeFromNib
{
    [self initialize];
}

- (void)initialize
{
    [self setImage:nil forState:UIControlStateNormal];
    [self setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [self setTitleColor:[UIColor blackColor] forState:UIControlStateHighlighted];
    
    self.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    self.backgroundColor = [UIColor colorWithWhite:0.8 alpha:1.0];
    self.layer.cornerRadius = 10;
    self.layer.borderWidth = 1;
    self.layer.borderColor = [UIColor colorWithWhite:0.7 alpha:1.0].CGColor;
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    if (self.highlighted) {
        self.backgroundColor = [UIColor colorWithWhite:0.6 alpha:1.0];
        self.layer.borderColor = [UIColor colorWithWhite:0.4 alpha:1.0].CGColor;
    }
    else {
        self.backgroundColor = [UIColor colorWithWhite:0.8 alpha:1.0];
        self.layer.borderColor = [UIColor colorWithWhite:0.7 alpha:1.0].CGColor;
    }
}

@end
