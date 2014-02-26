//
//  FindLocationViewController.m
//  ChatMarkers
//
//  Created by James McEvoy on 7/25/13.
//  Copyright (c) 2013 Chat Markers LLC. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>
#import <QuartzCore/QuartzCore.h>
#import "AppDelegate.h"
#import "Constants.h"
#import "FindLocationViewController.h"
#import "Server.h"

@interface FindLocationViewController () <CLLocationManagerDelegate>

@property(nonatomic,weak) IBOutlet MKMapView *mapView;

- (IBAction)findLocation;

@end

@implementation FindLocationViewController {
    CLLocationManager *_locationManager;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.mapView.userInteractionEnabled = NO;
    self.mapView.layer.borderColor = [UIColor lightGrayColor].CGColor;
    self.mapView.layer.borderWidth = 1;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    if ([[Server sharedInstance] isAuthorized]) {
        UIViewController *vc = [self.storyboard instantiateViewControllerWithIdentifier:@"TabBarController"];
        [AppDelegate sharedInstance].window.rootViewController = vc;
    }
    else if ([userDefaults doubleForKey:kUserDefaultsLatitude] && [userDefaults doubleForKey:kUserDefaultsLongitude]) {
        UIViewController *vc = [self.storyboard instantiateViewControllerWithIdentifier:@"FacebookViewController"];
        [self.navigationController pushViewController:vc animated:NO];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    if (_locationManager) {
        [_locationManager stopUpdatingLocation];
        _locationManager = nil;
    }
}

- (IBAction)findLocation
{
    if (!_locationManager) {
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;
        [_locationManager startUpdatingLocation];
    }
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager*)manager didUpdateLocations:(NSArray *)locations {
    CLLocation* location = [locations lastObject];
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setDouble:location.coordinate.latitude forKey:kUserDefaultsLatitude];
    [userDefaults setDouble:location.coordinate.longitude forKey:kUserDefaultsLongitude];
    
    [_locationManager stopUpdatingLocation];
    _locationManager = nil;
    
    [self performSegueWithIdentifier:@"RegistrationSegue" sender:nil];
}

@end
