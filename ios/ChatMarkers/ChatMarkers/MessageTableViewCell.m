//
//  MessageTableViewCell.m
//  ChatMarkers
//
//  Created by James McEvoy on 7/27/13.
//  Copyright (c) 2013 Chat Markers LLC. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "Message.h"
#import "MessageTableViewCell.h"
#import "Server.h"
#import "Thread.h"
#import "User.h"

@interface MessageTableViewCell()

@property(nonatomic,weak) IBOutlet UILabel *authorLabel;
@property(nonatomic,weak) IBOutlet UILabel *messageLabel;
@property(nonatomic,weak) IBOutlet UILabel *timeLabel;
@property(nonatomic,weak) IBOutlet UIImageView *profileImageView;
@property(nonatomic,weak) IBOutlet UIImageView *pictureView;
@property(nonatomic,weak) IBOutlet UIImageView *pictureBackgroundView;
@property(nonatomic,weak) IBOutlet UIView *pictureBackgroundOverlayView;
@property(nonatomic,weak) IBOutlet UIActivityIndicatorView *activityView;
@property(nonatomic,weak) IBOutlet NSLayoutConstraint *messageHeightConstraint;
@property(nonatomic,weak) IBOutlet UIView *leftView;
@property(nonatomic,weak) IBOutlet UIView *topView;

@end

@implementation MessageTableViewCell {
    Message *_message;
}

+ (UIFont*)textFont
{
    return [UIFont systemFontOfSize:16];
}

+ (CGFloat)heightForMessage:(Message*)message
{
    float height = [message.text sizeWithFont:[self textFont] constrainedToSize:CGSizeMake(240, MAXFLOAT) lineBreakMode:NSLineBreakByWordWrapping].height;
    height += 40;
    if (message.image.length) {
        height += 160;
    }
    return MAX(60, height);
}

- (void)setMessage:(Message*)message
{
    static NSDateFormatter *_dateDisplayFormatter, *_timeDisplayFormatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _dateDisplayFormatter = [[NSDateFormatter alloc] init];
        _dateDisplayFormatter.dateStyle = NSDateFormatterShortStyle;
        
        _timeDisplayFormatter = [[NSDateFormatter alloc] init];
        _timeDisplayFormatter.timeStyle = NSDateFormatterShortStyle;
    });
        
    self.topView.layer.shadowOpacity = 0.5;
    self.topView.layer.shadowRadius = 2;
    self.topView.layer.shadowOffset = CGSizeMake(0, 2);
    self.topView.layer.shadowPath = [UIBezierPath bezierPathWithRect:self.topView.bounds].CGPath;
    
    _message = message;
    self.messageLabel.font = [MessageTableViewCell textFont];
    
    float height = [message.text sizeWithFont:[MessageTableViewCell textFont] constrainedToSize:CGSizeMake(240, MAXFLOAT) lineBreakMode:NSLineBreakByWordWrapping].height;
    self.messageHeightConstraint.constant = height;
    [self layoutIfNeeded];
    
    self.authorLabel.text = message.user.displayName;
    self.messageLabel.text = message.text;
    
    self.image = nil;
    self.pictureView.image = nil;
    self.pictureBackgroundView.image = nil;
    self.pictureView.hidden = message.image.length == 0;
    self.pictureBackgroundView.hidden = self.pictureView.hidden;
    self.pictureBackgroundOverlayView.hidden = self.pictureView.hidden;
    [self.activityView stopAnimating];
    
    NSDate *time = [[Server sharedInstance] parseDate:message.time];
    if (- [time timeIntervalSinceNow] < 24 * 60 * 60) {
        self.timeLabel.text = [_timeDisplayFormatter stringFromDate:time];
    }
    else {
        self.timeLabel.text = [_dateDisplayFormatter stringFromDate:time];
    }
    
    self.profileImageView.image = nil;
    NSString *path = [NSString stringWithFormat:@"/threads/%@/users/%@", message.thread.remoteId, message.user.remoteId];
    [[Server sharedInstance] downloadFileAtPath:path completionHandler:^(NSString *filePath, NSError *error) {
        if (error) {
            // TODO show error image
            NSLog(@"Unable to download message image: %@", error);
        }
        else if (_message == message) {
            self.profileImageView.image = [UIImage imageWithContentsOfFile:filePath];
        }
    }];
    
    if (message.image) {
        [self.activityView startAnimating];
        
        NSString *path = [NSString stringWithFormat:@"/threads/%@/messages/%@", message.thread.remoteId, message.image];
        [[Server sharedInstance] downloadFileAtPath:path completionHandler:^(NSString *filePath, NSError *error) {
            if (error) {
                // TODO show error image
                NSLog(@"Unable to download message image: %@", error);
            }
            else if (_message == message) {
                self.image = [UIImage imageWithContentsOfFile:filePath];
                self.pictureView.image = self.image;
                self.pictureBackgroundView.image = self.image;
            }
            [self.activityView stopAnimating];
        }];
    }
}

@end
