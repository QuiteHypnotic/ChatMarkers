//
//  MarkerEditViewController.m
//  ChatMarkers
//
//  Created by James McEvoy on 7/28/13.
//  Copyright (c) 2013 Chat Markers LLC. All rights reserved.
//

#import <MapKit/MapKit.h>
#import "AppDelegate.h"
#import "CMAlertView.h"
#import "CMButton.h"
#import "CMLoadingView.h"
#import "Constants.h"
#import "MarkerEditViewController.h"
#import "MessagesViewController.h"
#import "NSManagedObjectContext+Utils.h"
#import "Server.h"
#import "ThreadsViewController.h"
#import "UIView+Utils.h"

@interface MarkerEditViewController () <UIGestureRecognizerDelegate,UITextFieldDelegate,MKMapViewDelegate>

@property(nonatomic,weak) IBOutlet UITextField *nameField, *passwordField, *expirationField;
@property(nonatomic,weak) IBOutlet UITextView *detailsField;
@property(nonatomic,weak) IBOutlet MKMapView *mapView;
@property(nonatomic,weak) IBOutlet UISlider *radiusSlider;
@property(nonatomic,weak) IBOutlet UILabel *radiusLabel;

- (IBAction)save;
- (IBAction)dismiss;

@end

@implementation MarkerEditViewController {
    BOOL _keyboardShown;
    UIDatePicker *_datePicker;
    MKCircle *_radialOverlay;
    NSDateFormatter *_dateFormatter;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UIButton *saveButton = [[CMButton alloc] initWithFrame:CGRectMake(10, 0, 300, 44)];
    [saveButton setTitle:@"Save" forState:UIControlStateNormal];
    [saveButton addTarget:self action:@selector(save) forControlEvents:UIControlEventTouchUpInside];
    
    UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 64)];
    [footerView addSubview:saveButton];
    self.tableView.tableFooterView = footerView;
    
    _dateFormatter = [[NSDateFormatter alloc] init];
    _dateFormatter.dateStyle = NSDateFormatterMediumStyle;
    _dateFormatter.timeStyle = NSDateFormatterShortStyle;
    
    _datePicker = [[UIDatePicker alloc] init];
    [_datePicker addTarget:self action:@selector(changeExpiration) forControlEvents:UIControlEventValueChanged];
    _datePicker.datePickerMode = UIDatePickerModeDateAndTime;
    _datePicker.minimumDate = [NSDate date];
    self.expirationField.inputView = _datePicker;
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    double latitude = [userDefaults doubleForKey:kUserDefaultsLatitude];
    double longitude = [userDefaults doubleForKey:kUserDefaultsLongitude];
    
    MKCoordinateRegion mapRegion;
    mapRegion.center = CLLocationCoordinate2DMake(latitude, longitude);
    mapRegion.span = MKCoordinateSpanMake(0.005, 0.005);
    [self.mapView setRegion:mapRegion animated: YES];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillChangeFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    
    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard:)];
    tapGestureRecognizer.delegate = self;
    [self.tableView addGestureRecognizer:tapGestureRecognizer];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillChangeFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}

- (IBAction)dismiss
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSString*)validate
{
    if (self.nameField.text.length == 0) {
        return @"You must enter a name for this marker.";
    }
    if (self.expirationField.text.length > 0 && [_datePicker.date compare:[NSDate date]] == NSOrderedAscending) {
        return @"The marker expiration must be in the future.";
    }
    if (self.detailsField.text.length == 0) {
        return @"You must enter a description for this marker.";
    }
    return nil;
}

- (IBAction)save
{
    [[self.view findFirstResponder] resignFirstResponder];
    
    NSString *error = [self validate];
    if (error) {
        [[CMAlertView alertWithTitle:@"Not quite there!" message:error] show];
    }
    else {
        NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
        params[@"name"] = self.nameField.text;
        params[@"details"] = self.detailsField.text;
        
        if (self.passwordField.text.length) {
            params[@"password"] = self.passwordField.text;
        }
        if (self.expirationField.text.length) {
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm.SSS'Z'"];
            params[@"expiration"] = [dateFormatter stringFromDate:_datePicker.date];
        }
        
        params[@"latitude"] = @(self.mapView.centerCoordinate.latitude);
        params[@"longitude"] = @(self.mapView.centerCoordinate.longitude);
        
        if (self.radiusSlider.value > self.radiusSlider.minimumValue) {
            params[@"radius"] = @(self.radiusSlider.value);
        }
        
        CMLoadingView *loadingView = [CMLoadingView showInView:self.navigationController.view message:nil];
        [[Server sharedInstance] executeMethod:@"POST" path:@"/threads" body:params completionHandler:^(NSDictionary *response, NSError *error) {
            if (error) {
                [loadingView dismiss];
                [[CMAlertView alertWithServerError:error reponse:nil] show];
            }
            else {
                NSManagedObjectContext *managedObjectContext = [AppDelegate sharedInstance].managedObjectContext;
                
                Thread *thread = [managedObjectContext upsertClass:[Thread class] column:@"remoteId" value:response[@"id"]];
                thread.latitude = response[@"latitude"];
                thread.longitude = response[@"longitude"];
                thread.name = response[@"name"];
                thread.unread = @(YES);
                
                if (response[@"radius"] != [NSNull null]) {
                    thread.radius = response[@"radius"];
                }
                
                [[Server sharedInstance] downloadMessages:thread completionHandler:^(NSError *error) {
                    [loadingView dismiss];
                    if (error) {
                        [[CMAlertView alertWithServerError:error reponse:nil] show];
                    }
                    else {
                        UITabBarController *tabBarController = (UITabBarController*) [AppDelegate sharedInstance].window.rootViewController;
                        [self dismissViewControllerAnimated:YES completion:nil];
                        
                        for (UINavigationController *navigation in tabBarController.viewControllers) {
                            if ([navigation.viewControllers[0] isKindOfClass:[ThreadsViewController class]]) {
                                [tabBarController setSelectedViewController:navigation];
                                [navigation popToRootViewControllerAnimated:NO];
                                
                                MessagesViewController *vc = [self.storyboard instantiateViewControllerWithIdentifier:@"MessagesViewController"];
                                vc.thread = thread;
                                [navigation pushViewController:vc animated:NO];
                                break;
                            }
                        }
                    }
                }];
            }
        }];
    }
}

- (IBAction)showPasswordHelp
{
    [[CMAlertView alertWithTitle:@"Password" message:@"This marker will still be visible on the map, but users will need to enter the password to join."] show];
}

- (IBAction)showExpirationHelp
{
    [[CMAlertView alertWithTitle:@"Expiration" message:@"After the expiration, this marker will no longer be visible on the map.  However, anyone who previously joined will still have access to an archive of photos and messages."] show];
}

- (void)changeExpiration
{
    self.expirationField.text = [_dateFormatter stringFromDate:_datePicker.date];
}

- (IBAction)changeRadiusSlider
{
    if (_radialOverlay) {
        [self.mapView removeOverlay:_radialOverlay];
    }
    
    if (self.radiusSlider.value == self.radiusSlider.minimumValue) {
        self.radiusLabel.text = @"No Limit";
    }
    else {
        if (self.radiusSlider.value >= 1000) {
            self.radiusLabel.text = [NSString stringWithFormat:@"%.2f km", self.radiusSlider.value / 1000.0f];
        }
        else {
            self.radiusLabel.text = [NSString stringWithFormat:@"%d m", (int) self.radiusSlider.value];
        }
        _radialOverlay = [MKCircle circleWithCenterCoordinate:self.mapView.centerCoordinate radius:self.radiusSlider.value];
        [self.mapView addOverlay:_radialOverlay];
    }
}

- (void)dismissKeyboard:(UITapGestureRecognizer*)gestureRecognizer
{
    if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
        [[self.view findFirstResponder] resignFirstResponder];
    }
}

- (void)keyboardWillShow:(NSNotification *)notification {
    _keyboardShown = YES;
}

- (void)keyboardWillHide:(NSNotification *)notification {
    _keyboardShown = NO;
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField == self.nameField) {
        [self.passwordField becomeFirstResponder];
    }
    else if (textField == self.passwordField) {
        [self.expirationField becomeFirstResponder];
    }
    return YES;
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    return _keyboardShown;
}

#pragma mark - MKMapViewDelegate

- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated
{
    if (_radialOverlay) {
        [self.mapView removeOverlay:_radialOverlay];
        _radialOverlay = [MKCircle circleWithCenterCoordinate:self.mapView.centerCoordinate radius:self.radiusSlider.value];
        [self.mapView addOverlay:_radialOverlay];
    }
}

- (MKOverlayView *)mapView:(MKMapView *)map viewForOverlay:(id <MKOverlay>)overlay
{
    MKCircleView *circleView = [[MKCircleView alloc] initWithCircle:overlay];
    circleView.lineWidth = 1;
    circleView.strokeColor = [UIColor greenColor];
    circleView.fillColor = [[UIColor greenColor] colorWithAlphaComponent:0.2];
    return circleView;
}

- (MKAnnotationView*)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation
{
    return nil;
}

@end
