//
//  MessageTableViewCell.h
//  ChatMarkers
//
//  Created by James McEvoy on 7/27/13.
//  Copyright (c) 2013 Chat Markers LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Message.h"

@interface MessageTableViewCell : UITableViewCell

@property(nonatomic,strong) UIImage *image;

+ (CGFloat)heightForMessage:(Message*)message;
- (void)setMessage:(Message*)message;

@end
