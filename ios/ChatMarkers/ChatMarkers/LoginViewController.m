//
//  LoginViewController.m
//  ChatMarkers
//
//  Created by James McEvoy on 7/25/13.
//  Copyright (c) 2013 Chat Markers LLC. All rights reserved.
//

#import <FacebookSDK/FacebookSDK.h>
#import <QuartzCore/QuartzCore.h>
#import "AppDelegate.h"
#import "CMAlertView.h"
#import "CMLoadingView.h"
#import "Constants.h"
#import "LoginViewController.h"
#import "Server.h"
#import "UIView+Utils.h"

@interface LoginViewController () <UITextFieldDelegate>

@property(nonatomic,weak) IBOutlet UITextField *emailField, *passwordField;
@property(nonatomic,weak) IBOutlet UIView *loginView;
@property(nonatomic,weak) IBOutlet NSLayoutConstraint *bottomMarginConstraint;

- (IBAction)dismissKeyboard;
- (IBAction)loginWithEmail;
- (IBAction)loginWithFacebook;

@end

@implementation LoginViewController {
    BOOL _keyboardShown;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.navigationItem.hidesBackButton = YES;
    
    self.loginView.layer.borderWidth = 1;
    self.loginView.layer.borderColor = [UIColor lightGrayColor].CGColor;
    self.loginView.layer.cornerRadius = 10;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillChangeFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillChangeFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}

- (IBAction)dismissKeyboard
{
    [[self.view findFirstResponder] resignFirstResponder];
}

- (void)keyboardWillShow:(NSNotification *)notification {
    if (_keyboardShown) return;
    _keyboardShown = !_keyboardShown;
    
    NSDictionary *info = [notification userInfo];
    NSValue *kbFrame = [info objectForKey:UIKeyboardFrameEndUserInfoKey];
    NSTimeInterval animationDuration = [[info objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    CGRect keyboardFrame = [kbFrame CGRectValue];
    
    self.bottomMarginConstraint.constant = -keyboardFrame.size.height;
    [UIView animateWithDuration:animationDuration animations:^{
        [self.view layoutIfNeeded];
    }];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    if (!_keyboardShown) return;
    _keyboardShown = !_keyboardShown;
    
    NSDictionary *info = [notification userInfo];
    NSTimeInterval animationDuration = [[info objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    
    self.bottomMarginConstraint.constant = 0;
    [UIView animateWithDuration:animationDuration animations:^{
        [self.view layoutIfNeeded];
    }];
}

- (void)showMainTabs
{
    UIViewController *vc = [self.storyboard instantiateViewControllerWithIdentifier:@"TabBarController"];
    [AppDelegate sharedInstance].window.rootViewController = vc;
}

- (IBAction)loginWithEmail
{
    CMLoadingView *loadingView = [CMLoadingView showInView:self.navigationController.view message:nil];
    
    NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
    params[@"email"] = self.emailField.text;
    params[@"password"] = self.passwordField.text;
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString *pushToken = [userDefaults objectForKey:kUserDefaultsPushNotificationToken];
    if (pushToken) {
        params[@"device_type"] = @"ios";
        params[@"device_id"] = pushToken;
    }

    [[Server sharedInstance] executeMethod:@"POST" path:@"/sessions" body:params completionHandler:^(NSDictionary *response, NSError *error) {
        [loadingView dismiss];
        if (error) {
            [[CMAlertView alertWithServerError:error reponse:response] show];
        }
        else {
            [self showMainTabs];
        }
    }];
}

- (IBAction)loginWithFacebook
{
    __weak LoginViewController *_self = self;
    [FBSession openActiveSessionWithReadPermissions:@[@"email"] allowLoginUI:YES completionHandler:^(FBSession *session, FBSessionState status, NSError *error) {
        if (status == FBSessionStateOpen) {
            [_self completeFacebookLogin];
        }
    }];
}

- (void)registerWithFacebook:(id<FBGraphUser>)user
{
    CMLoadingView *loadingView = [CMLoadingView showInView:self.navigationController.view message:nil];

    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
    params[@"facebook"] = FBSession.activeSession.accessTokenData.accessToken;
    params[@"latitude"] = @([userDefaults doubleForKey:kUserDefaultsLatitude]);
    params[@"longitude"] = @([userDefaults doubleForKey:kUserDefaultsLongitude]);
    
    NSString *pushToken = [userDefaults objectForKey:kUserDefaultsPushNotificationToken];
    if (pushToken) {
        params[@"device_type"] = @"ios";
        params[@"device_id"] = pushToken;
    }
    
    [[Server sharedInstance] executeMethod:@"POST" path:@"/users" body:params completionHandler:^(NSDictionary *response, NSError *error) {
        [loadingView dismiss];
        if (error) {
            [[CMAlertView alertWithServerError:error reponse:response] show];
        }
        else {
            [self showMainTabs];
        }
    }];
}

- (void)completeFacebookLogin
{    
    CMLoadingView *loadingView = [CMLoadingView showInView:self.navigationController.view message:nil];
    
    [[FBRequest requestForMe] startWithCompletionHandler:^(FBRequestConnection *connection, id<FBGraphUser> user, NSError *error) {
        if (error) {
            [[CMAlertView alertWithErrorMessage:@"We were unable to connect to Facebook at this time."] show];
        }
        else {
            NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
            params[@"facebook"] = FBSession.activeSession.accessTokenData.accessToken;
            
            NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
            NSString *pushToken = [userDefaults objectForKey:kUserDefaultsPushNotificationToken];
            if (pushToken) {
                params[@"device_type"] = @"ios";
                params[@"device_id"] = pushToken;
            }
            
            [[Server sharedInstance] executeMethod:@"POST" path:@"/sessions" body:params completionHandler:^(NSDictionary *response, NSError *error) {
                [loadingView dismiss];
                
                if (error) {
                    if ([error.domain isEqualToString:kAPIErrorDomain] && error.code == kHttpStatusCodeError) {
                        int statusCode = [error.userInfo[kHttpStatusCodeKey] intValue];
                        if (statusCode == 404) {
                            [self registerWithFacebook:user];
                            return;
                        }
                    }
                    [[CMAlertView alertWithServerError:error reponse:response] show];
                }
                else {
                    [self showMainTabs];
                }
            }];
        }
    }];
}

#pragma mark - UITextFieldDelgate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField == self.emailField) {
        [self.passwordField becomeFirstResponder];
    }
    else {
        [textField resignFirstResponder];
        [self loginWithEmail];
    }
    return YES;
}

@end
