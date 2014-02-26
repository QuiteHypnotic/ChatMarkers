//
//  AppDelegate.h
//  ChatMarkers
//
//  Created by James McEvoy on 7/24/13.
//  Copyright (c) 2013 Chat Markers LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property(strong,nonatomic) UIWindow *window;

@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

+ (AppDelegate*)sharedInstance;
- (void)logout;
- (void)saveContext;
- (NSURL *)applicationDocumentsDirectory;

@end
