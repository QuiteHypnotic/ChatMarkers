//
//  AppDelegate.m
//  ChatMarkers
//
//  Created by James McEvoy on 7/24/13.
//  Copyright (c) 2013 Chat Markers LLC. All rights reserved.
//

#import <FacebookSDK/FacebookSDK.h>
#import "AppDelegate.h"
#import "CMAlertView.h"
#import "CMNavigationBar.h"
#import "Constants.h"
#import "Message.h"
#import "MessagesViewController.h"
#import "Server.h"
#import "Thread.h"
#import "ThreadsViewController.h"
#import "UIColor+Theme.h"
#import "User.h"

@implementation AppDelegate

@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

+ (AppDelegate*)sharedInstance
{
    return [UIApplication sharedApplication].delegate;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    if (![userDefaults objectForKey:kUserDefaultsFirstLaunch]) {
        [[Server sharedInstance] removeAccessToken];
        [userDefaults setObject:@(YES) forKey:kUserDefaultsFirstLaunch];
    }
    
    if ([[Server sharedInstance] isAuthorized]) {
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"MainStoryboard" bundle:nil];
        self.window.rootViewController = [storyboard instantiateViewControllerWithIdentifier:@"TabBarController"];
    }

    [FBLoginView class];
    
    [[UIBarButtonItem appearanceWhenContainedIn:[CMNavigationBar class], nil] setBackgroundImage:[[UIImage alloc] init] forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    
    [[UISegmentedControl appearanceWhenContainedIn:[CMNavigationBar class], nil] setBackgroundImage:[[UIImage alloc] init] forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    [[UISegmentedControl appearanceWhenContainedIn:[CMNavigationBar class], nil] setDividerImage:[UIImage imageNamed:@"navigation_divider"] forLeftSegmentState:UIControlStateNormal rightSegmentState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    [[UISegmentedControl appearanceWhenContainedIn:[CMNavigationBar class], nil] setDividerImage:[UIImage imageNamed:@"navigation_divider"] forLeftSegmentState:UIControlStateSelected rightSegmentState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    [[UISegmentedControl appearanceWhenContainedIn:[CMNavigationBar class], nil] setDividerImage:[UIImage imageNamed:@"navigation_divider"] forLeftSegmentState:UIControlStateNormal rightSegmentState:UIControlStateSelected barMetrics:UIBarMetricsDefault];
    
    [application registerForRemoteNotificationTypes:(UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert)];
    
    //[userDefaults setObject:@"13B21B966EE9D09421A9EC58CC3AFA33B3D7DC1108D4201EEDCB6F5ADFC1E3A3" forKey:kUserDefaultsPushNotificationToken];
    
    NSDictionary *remoteNotification = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
    if (remoteNotification) {
        [self application:application didReceiveRemoteNotification:remoteNotification];
    }
    
    return YES;
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    return [FBSession.activeSession handleOpenURL:url];
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    const char* data = [deviceToken bytes];
    NSMutableString* token = [NSMutableString string];
    
    for (int i = 0; i < [deviceToken length]; i++) {
        [token appendFormat:@"%02.2hhX", data[i]];
    }
    
    // iPhone 4S - E4C3E4545482D28D3393FDDEFE43F8610448376033EF22070AF46E385671CFFE
    // iPod Touch 4G - 13B21B966EE9D09421A9EC58CC3AFA33B3D7DC1108D4201EEDCB6F5ADFC1E3A3
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:token forKey:kUserDefaultsPushNotificationToken];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass([Thread class])];
    request.predicate = [NSPredicate predicateWithFormat:@"remoteId == %@", userInfo[@"thread"]];
    
    Thread *thread = [[self.managedObjectContext executeFetchRequest:request error:nil] lastObject];
    
    if (thread) {
        [[Server sharedInstance] downloadMessages:thread completionHandler:nil];
        
        if (application.applicationState != UIApplicationStateActive) {
            UITabBarController *tabBarController = (UITabBarController*) self.window.rootViewController;
            
            for (UINavigationController *navigation in tabBarController.viewControllers) {
                if ([navigation.viewControllers[0] isKindOfClass:[ThreadsViewController class]]) {
                    [tabBarController setSelectedViewController:navigation];
                    [navigation popToRootViewControllerAnimated:NO];
                    
                    MessagesViewController *vc = [tabBarController.storyboard instantiateViewControllerWithIdentifier:@"MessagesViewController"];
                    vc.thread = thread;
                    [navigation pushViewController:vc animated:NO];
                    break;
                }
            }
        }
    }
    else {
        [[Server sharedInstance] downloadThreadsWithCompletionHandler:nil];
    }
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}


- (void)applicationWillTerminate:(UIApplication *)application
{
    // Saves changes in the application's managed object context before the application terminates.
    [self saveContext];
}

- (void)saveContext
{
    NSError *error = nil;
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil) {
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }
}

- (void)logout
{
    [[Server sharedInstance] removeAccessToken];
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass([Thread class])];
    NSArray *threads = [self.managedObjectContext executeFetchRequest:request error:nil];
    for (Thread *thread in threads) {
        [self.managedObjectContext deleteObject:thread];
    }
    request = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass([User class])];
    NSArray *users = [self.managedObjectContext executeFetchRequest:request error:nil];
    for (User *user in users) {
        [self.managedObjectContext deleteObject:user];
    }
    request = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass([Message class])];
    NSArray *messages = [self.managedObjectContext executeFetchRequest:request error:nil];
    for (Message *message in messages) {
        [self.managedObjectContext deleteObject:message];
    }
    
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"MainStoryboard" bundle:nil];
    self.window.rootViewController = [storyboard instantiateInitialViewController];
}

#pragma mark - Core Data stack

// Returns the managed object context for the application.
// If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        _managedObjectContext = [[NSManagedObjectContext alloc] init];
        [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    }
    return _managedObjectContext;
}

// Returns the managed object model for the application.
// If the model doesn't already exist, it is created from the application's model.
- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"ChatMarkers" withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

// Returns the persistent store coordinator for the application.
// If the coordinator doesn't already exist, it is created and the application's store added to it.
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"ChatMarkers.sqlite"];
    
    NSError *error = nil;
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
        /*
         Replace this implementation with code to handle the error appropriately.
         
         abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
         
         Typical reasons for an error here include:
         * The persistent store is not accessible;
         * The schema for the persistent store is incompatible with current managed object model.
         Check the error message to determine what the actual problem was.
         
         
         If the persistent store is not accessible, there is typically something wrong with the file path. Often, a file URL is pointing into the application's resources directory instead of a writeable directory.
         
         If you encounter schema incompatibility errors during development, you can reduce their frequency by:
         * Simply deleting the existing store:
         [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil]
         
         * Performing automatic lightweight migration by passing the following dictionary as the options parameter:
         @{NSMigratePersistentStoresAutomaticallyOption:@YES, NSInferMappingModelAutomaticallyOption:@YES}
         
         Lightweight migration will only work for a limited set of schema changes; consult "Core Data Model Versioning and Data Migration Programming Guide" for details.
         
         */
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    return _persistentStoreCoordinator;
}

#pragma mark - Application's Documents directory

// Returns the URL to the application's Documents directory.
- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

@end
