//
//  MarkerPasswordViewController.m
//  ChatMarkers
//
//  Created by James McEvoy on 8/4/13.
//  Copyright (c) 2013 Chat Markers LLC. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "CMAlertView.h"
#import "CMLoadingView.h"
#import "MarkerPasswordViewController.h"
#import "MessagesViewController.h"
#import "Server.h"
#import "ThreadsViewController.h"

@interface MarkerPasswordViewController () <UITextFieldDelegate>

@property(nonatomic,weak) IBOutlet UITextField *passwordField;

- (IBAction)submit;

@end

@implementation MarkerPasswordViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UIButton *backButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [backButton setImage:[UIImage imageNamed:@"btn_back"] forState:UIControlStateNormal];
    [backButton addTarget:self action:@selector(back) forControlEvents:UIControlEventTouchUpInside];
    backButton.frame = CGRectMake(0, 0, 40, 40);
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:backButton];
    
    self.title = self.thread.name;
    
    [self.passwordField becomeFirstResponder];
    self.passwordField.layer.borderWidth = 1;
    self.passwordField.layer.borderColor = [UIColor lightGrayColor].CGColor;
    self.passwordField.layer.cornerRadius = 10;
}

- (void)back
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction)submit
{
    CMLoadingView *loadingView = [CMLoadingView showInView:self.navigationController.view message:nil];
    [[Server sharedInstance] subscribeThread:self.thread password:self.passwordField.text completionHandler:^(NSError *error) {
        [loadingView dismiss];
        
        if (error) {
            if ([error.domain isEqualToString:kAPIErrorDomain] && error.code == kHttpStatusCodeError && [error.userInfo[kHttpStatusCodeKey] intValue] == 403) {
                [[CMAlertView alertWithTitle:@"Incorrect Password" message:@"The password you entered was not correct. Please try again."] show];
                self.passwordField.text = @"";
            }
            else {
                [[CMAlertView alertWithServerError:error reponse:nil] show];
            }
        }
        else {
            UITabBarController *tabBarController = self.tabBarController;
            [self.navigationController popViewControllerAnimated:NO];
            
            for (UINavigationController *navigation in tabBarController.viewControllers) {
                if ([navigation.viewControllers[0] isKindOfClass:[ThreadsViewController class]]) {
                    [tabBarController setSelectedViewController:navigation];
                    [navigation popToRootViewControllerAnimated:NO];
                    
                    MessagesViewController *vc = [self.storyboard instantiateViewControllerWithIdentifier:@"MessagesViewController"];
                    vc.thread = self.thread;
                    [navigation pushViewController:vc animated:NO];
                    break;
                }
            }
        }
    }];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self submit];
    return YES;
}

@end
