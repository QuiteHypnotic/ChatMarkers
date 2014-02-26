//
//  CreateAccountViewController.m
//  ChatMarkers
//
//  Created by James McEvoy on 7/30/13.
//  Copyright (c) 2013 Chat Markers LLC. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "AppDelegate.h"
#import "CMAlertView.h"
#import "CMLoadingView.h"
#import "Constants.h"
#import "CreateAccountViewController.h"
#import "Server.h"
#import "UIView+Utils.h"

@interface CreateAccountViewController () <UITextFieldDelegate,UIImagePickerControllerDelegate,UIActionSheetDelegate,UINavigationControllerDelegate>

@property(nonatomic,weak) IBOutlet UIView *formView;
@property(nonatomic,weak) IBOutlet UIImageView *profileImageView;
@property(nonatomic,weak) IBOutlet UIScrollView *scrollView;
@property(nonatomic,weak) IBOutlet UITextField *firstNameField, *lastNameField, *emailField, *passwordField, *confirmPasswordField;
@property(nonatomic,weak) IBOutlet NSLayoutConstraint *bottomMarginConstraint;

- (IBAction)createAccount;
- (IBAction)dismissKeyboard;
- (IBAction)showImagePicker;

@end

@implementation CreateAccountViewController {
    BOOL _keyboardShown;
    UIImage *_profileImage;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.formView.layer.cornerRadius = 10;
    self.formView.layer.borderWidth = 1;
    self.formView.layer.borderColor = [UIColor lightGrayColor].CGColor;
    
    CGSize size = CGSizeMake(self.scrollView.frame.size.width, 0);
    for (UIView *view in self.scrollView.subviews) {
        float height = CGRectGetMaxY(view.frame) + 20;
        if (height > size.height) {
            size.height = height;
        }
    }
    self.scrollView.contentSize = size;
    
    UIButton *backButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [backButton setImage:[UIImage imageNamed:@"btn_back"] forState:UIControlStateNormal];
    [backButton addTarget:self action:@selector(back) forControlEvents:UIControlEventTouchUpInside];
    backButton.frame = CGRectMake(0, 0, 40, 40);
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:backButton];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillChangeFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillChangeFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}

- (void)back
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction)dismissKeyboard
{
    [[self.view findFirstResponder] resignFirstResponder];
}

- (NSString*)validate
{
    if (self.firstNameField.text.length == 0) {
        return @"You must enter your first name.";
    }
    if (self.lastNameField.text.length == 0) {
        return @"You must enter your last name.";
    }
    if (self.emailField.text.length == 0) {
        return @"You must enter an email address.";
    }
    if ([self.emailField.text rangeOfString:@"@"].location == NSNotFound) {
        return @"You must enter a valid email address.";
    }
    if (self.passwordField.text.length == 0) {
        return @"You must enter a password.";
    }
    if (![self.passwordField.text isEqualToString:self.confirmPasswordField.text]) {
        return @"Your password and confirmation do not match.";
    }
    if (_profileImage == nil) {
        return @"You must select a profile image.";
    }
    return nil;
}

- (IBAction)createAccount
{
    [self dismissKeyboard];
    
    NSString *error = [self validate];
    if (error) {
        [[CMAlertView alertWithTitle:@"Not quite there!" message:error] show];
    }
    else {
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        
        NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
        params[@"first_name"] = self.firstNameField.text;
        params[@"last_name"] = self.lastNameField.text;
        params[@"email"] = self.emailField.text;
        params[@"password"] = self.passwordField.text;
        params[@"latitude"] = @([userDefaults doubleForKey:kUserDefaultsLatitude]);
        params[@"longitude"] = @([userDefaults doubleForKey:kUserDefaultsLongitude]);
        
        NSString *pushToken = [userDefaults objectForKey:kUserDefaultsPushNotificationToken];
        if (pushToken) {
            params[@"device_type"] = @"ios";
            params[@"device_id"] = pushToken;
        }
        
        CMLoadingView *loadingView = [CMLoadingView showInView:self.navigationController.view message:nil];
        
        NSData *data = UIImageJPEGRepresentation(_profileImage, 1.0);
        [[Server sharedInstance] uploadFilePath:@"/users" params:params filename:@"image" contentType:@"image/jpeg" data:data completionHandler:^(NSDictionary *response, NSError *error) {
            [loadingView dismiss];
            if (error) {
                [[CMAlertView alertWithServerError:error reponse:response] show];
            }
            else {
                UIViewController *vc = [self.storyboard instantiateViewControllerWithIdentifier:@"TabBarController"];
                [AppDelegate sharedInstance].window.rootViewController = vc;
            }
        }];
    }
}

- (IBAction)showImagePicker
{
    UIActionSheet *actionSheet = nil;
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        actionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"Browse Gallery", @"Take Picture", nil];
    }
    else {
        actionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"Browse Gallery", nil];
    }
    actionSheet.actionSheetStyle = UIActionSheetStyleBlackOpaque;
    [actionSheet showInView:self.view];
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

#pragma mark - UITextFieldDelgate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField == self.firstNameField) {
        [self.lastNameField becomeFirstResponder];
    }
    else if (textField == self.lastNameField) {
        [self.emailField becomeFirstResponder];
    }
    else if (textField == self.emailField) {
        [self.passwordField becomeFirstResponder];
    }
    else if (textField == self.passwordField) {
        [self.confirmPasswordField becomeFirstResponder];
    }
    else if (textField == self.confirmPasswordField) {
        [self createAccount];
    }
    return YES;
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex < actionSheet.cancelButtonIndex) {
        UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
        
        if (buttonIndex == 0) {
            imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        }
        else {
            imagePicker.sourceType = UIImagePickerControllerSourceTypeCamera;
        }
        imagePicker.delegate = self;
        imagePicker.allowsEditing = YES;
        [self presentViewController:imagePicker animated:YES completion:nil];
    }
}

#pragma mark = UIImagePickerControllerDelegate

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    [self dismissViewControllerAnimated:YES completion:nil];
    
    UIImage *image = [info objectForKey:UIImagePickerControllerEditedImage];
    float scale = MIN(100 / image.size.width, 100 / image.size.height);
    
    float size = MAX(scale * image.size.width, scale * image.size.height);
    CGRect frame = CGRectMake(0, 0, size, size);
    CGRect drawFrame = CGRectMake(0, 0, scale * image.size.width, scale * image.size.height);
    drawFrame.origin.x = (frame.size.width - drawFrame.size.width) / 2;
    drawFrame.origin.y = (frame.size.height - drawFrame.size.height) / 2;
    
    UIGraphicsBeginImageContext(frame.size);
    [[UIColor blackColor] setFill];
    [[UIBezierPath bezierPathWithRect:frame] fill];
    [image drawInRect:drawFrame];
    image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    _profileImage = image;
    self.profileImageView.image = _profileImage;
}

@end
