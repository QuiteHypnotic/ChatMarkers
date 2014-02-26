//
//  SettingsViewController.m
//  ChatMarkers
//
//  Created by James McEvoy on 8/4/13.
//  Copyright (c) 2013 Chat Markers LLC. All rights reserved.
//

#import "AppDelegate.h"
#import "SettingsViewController.h"

@interface SettingsViewController ()

- (IBAction)logout;

@end

@implementation SettingsViewController

- (IBAction)logout
{
    [[AppDelegate sharedInstance] logout];
}

@end
