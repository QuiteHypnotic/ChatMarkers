//
//  CMAlertView.m
//  ChatMarkers
//
//  Created by James McEvoy on 7/26/13.
//  Copyright (c) 2013 Chat Markers LLC. All rights reserved.
//

#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import "CMAlertView.h"
#import "CMButton.h"
#import "UIView+Utils.h"

static char kAssocKeyAlertView;
static NSString *kErrorTitle = @"Sorry about that!";

@interface CMAlertView()

@property(nonatomic,strong) NSString *title, *message;
@property(nonatomic,weak) IBOutlet UIView *alertView, *dialogView;
@property(nonatomic,weak) IBOutlet UILabel *titleLabel, *messageLabel;
@property(nonatomic,weak) IBOutlet NSLayoutConstraint *dialogHeightConstraint;

@end

@implementation CMAlertView {
    NSMutableArray *_buttons;
}

+ (CMAlertView*)alertWithServerError:(NSError*)error reponse:(NSDictionary*)response
{
    NSString *message = [response objectForKey:@"error"];
    if (!message) {
        message = @"We aren't able to connect to our servers at the moment.";
    }
    return [self alertWithTitle:kErrorTitle message:message];
}

+ (CMAlertView*)alertWithErrorMessage:(NSString*)message
{
    return [self alertWithTitle:kErrorTitle message:message];
}

+ (CMAlertView*)alertWithTitle:(NSString*)title message:(NSString*)message
{
    return [[CMAlertView alloc] initWithTitle:title message:message];
}

- (id)initWithTitle:(NSString*)title message:(NSString*)message
{
    if (self = [super init]) {
        _title = title;
        _message = message;
        _buttons = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)addButton:(NSString*)title action:(void(^)(CMAlertView *view))action
{
    [_buttons addObject:@[title, [action copy]]];
}

- (void)show
{
    if (_buttons.count == 0) {
        [_buttons addObject:@[@"OK", [^(CMAlertView *view) {
            [view dismiss];
        } copy]]];
    }
    
    NSArray *windows = [UIApplication sharedApplication].windows;
    for (UIWindow *window in windows) {
        if (!window.hidden) {
            [[window findFirstResponder] resignFirstResponder];
            
            _alertView = [[[NSBundle mainBundle] loadNibNamed:@"CMAlertView" owner:self options:nil] objectAtIndex:0];
            _alertView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
            objc_setAssociatedObject(_alertView, &kAssocKeyAlertView, self, OBJC_ASSOCIATION_RETAIN);

            self.titleLabel.text = _title;
            self.messageLabel.text = _message;
            
            float height = [_message sizeWithFont:self.messageLabel.font constrainedToSize:CGSizeMake(self.messageLabel.frame.size.width, MAXFLOAT)].height;
            self.dialogHeightConstraint.constant = self.messageLabel.frame.origin.y + height + 80;
            
            float padding = 20;
            float width = (self.dialogView.frame.size.width - padding * (_buttons.count + 1)) / _buttons.count;
            float x = padding;
            float y = self.messageLabel.frame.origin.y + height + 20;
            int index = 0;
            for (NSArray *values in _buttons) {
                CMButton *button = [[CMButton alloc] init];
                button.frame = CGRectMake(x, y, width, 40);
                [button setTitle:values[0] forState:UIControlStateNormal];
                [button addTarget:self action:@selector(didSelectButton:) forControlEvents:UIControlEventTouchUpInside];
                button.tag = index;
                [self.dialogView addSubview:button];
                x += width + padding;
                index++;
            }
            
            self.dialogView.layer.borderWidth = 1;
            self.dialogView.layer.borderColor = [UIColor lightGrayColor].CGColor;
            self.dialogView.layer.cornerRadius = 4;
            self.dialogView.layer.shadowOpacity = 1.0;
            
            _alertView.frame = window.bounds;
            _alertView.alpha = 0.0f;
            [window addSubview:_alertView];
            [UIView animateWithDuration:0.5 animations:^() {
                _alertView.alpha = 1.0;
            }];
            return;
        }
    }
}

- (void)dismiss
{
    [UIView animateWithDuration:0.5 animations:^() {
        _alertView.alpha = 0.0f;
    } completion:^(BOOL finished) {
        [_alertView removeFromSuperview];
    }];
}

- (void)didSelectButton:(CMButton*)button
{
    NSArray *values = _buttons[button.tag];
    void(^action)(CMAlertView *view) = values[1];
    action(self);
}

@end
