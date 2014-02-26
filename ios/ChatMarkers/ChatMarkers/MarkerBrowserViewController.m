//
//  MarkerBrowserViewController.m
//  ChatMarkers
//
//  Created by James McEvoy on 7/28/13.
//  Copyright (c) 2013 Chat Markers LLC. All rights reserved.
//

#import <MapKit/MapKit.h>
#import "AppDelegate.h"
#import "CMAlertView.h"
#import "CMLoadingView.h"
#import "Constants.h"
#import "MarkerAnnotation.h"
#import "MarkerBrowserViewController.h"
#import "MarkerPasswordViewController.h"
#import "MessagesViewController.h"
#import "NSManagedObjectContext+Utils.h"
#import "Server.h"
#import "Thread.h"

@interface MarkerBrowserViewController () <UITableViewDelegate,UITableViewDataSource,CLLocationManagerDelegate,MKMapViewDelegate,NSFetchedResultsControllerDelegate>

@property(nonatomic,weak) IBOutlet MKMapView *mapView;
@property(nonatomic,weak) IBOutlet UITableView *tableView;

- (IBAction)setDisplayMode:(UISegmentedControl*)control;

@end

@implementation MarkerBrowserViewController {
    CLLocation *_location;
    CLLocationManager *_locationManager;
    NSManagedObjectContext *_managedObjectContext;
    NSFetchedResultsController *_fetchedResultsController;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	self.mapView.hidden = NO;
    self.tableView.hidden = YES;
    
    _locationManager = [[CLLocationManager alloc] init];
    _locationManager.delegate = self;
    
    _managedObjectContext = [AppDelegate sharedInstance].managedObjectContext;
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass([Thread class])];
    request.predicate = [NSPredicate predicateWithFormat:@"distance != NULL AND (radius = NULL OR radius > distance)"];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"distance" ascending:YES]];
    
    NSError *error = nil;
    _fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:request managedObjectContext:_managedObjectContext sectionNameKeyPath:nil cacheName:nil];
    _fetchedResultsController.delegate = self;
    [_fetchedResultsController performFetch:&error];
    if (error) {
        NSLog(@"Unable to fetch nearby threads: %@", error);
    }
    [self.tableView reloadData];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [_locationManager startUpdatingLocation];
    
    if (_location) {
        [self downloadMarkers];
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [_locationManager stopUpdatingLocation];
}

- (void)downloadMarkers
{
    [[Server sharedInstance] downloadThreadsNearLocation:_location completionHandler:^(NSArray *threads, NSError *error) {
        if (error) {
            [[CMAlertView alertWithServerError:error reponse:nil] show];
        }
        else {
            [self recalculateMarkerDistances];
        }
    }];
}

- (void)recalculateMarkerDistances
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass([Thread class])];
    NSArray *threads = [_managedObjectContext executeFetchRequest:request error:nil];
    
    for (id<MKAnnotation> annotation in self.mapView.annotations.copy) {
        if ([annotation isKindOfClass:[MarkerAnnotation class]]) {
            [self.mapView removeAnnotation:annotation];
        }
    }
    
    for (Thread *thread in threads) {
        if (!thread.radius || thread.radius.doubleValue > thread.distance.doubleValue) {
            [self.mapView addAnnotation:[[MarkerAnnotation alloc] initWithThread:thread]];
        }
    }
}

- (IBAction)setDisplayMode:(UISegmentedControl*)control
{
    if (control.selectedSegmentIndex == 0) {
        self.mapView.hidden = NO;
        self.tableView.hidden = YES;
    }
    else {
        self.mapView.hidden = YES;
        self.tableView.hidden = NO;
    }
}

- (void)selectThread:(Thread*)thread
{
    if (thread.me || !thread.password.boolValue) {
        MessagesViewController *vc = [self.storyboard instantiateViewControllerWithIdentifier:@"MessagesViewController"];
        vc.thread = thread;
        [self.navigationController pushViewController:vc animated:YES];
    }
    else {
        [self performSegueWithIdentifier:@"MarkerPasswordSegue" sender:thread];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.destinationViewController isKindOfClass:[MarkerPasswordViewController class]]) {
        MarkerPasswordViewController *vc = (MarkerPasswordViewController*) segue.destinationViewController;
        vc.thread = sender;
    }
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    CLLocation *location = [locations lastObject];
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setDouble:location.coordinate.latitude forKey:kUserDefaultsLatitude];
    [userDefaults setDouble:location.coordinate.longitude forKey:kUserDefaultsLongitude];
    
    if (!_location) {
        _location = location;
        MKCoordinateRegion mapRegion;
        mapRegion.center = _location.coordinate;
        mapRegion.span = MKCoordinateSpanMake(0.2, 0.2);
        [self.mapView setRegion:mapRegion animated: YES];
        [self downloadMarkers];
    }
    else if ([_location distanceFromLocation:location] > 5) {
        _location = location;
        [self recalculateMarkerDistances];
    }
}

#pragma mark - UITableViewDelegate and UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [[_fetchedResultsController sections] count];
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
    id <NSFetchedResultsSectionInfo> sectionInfo = [[_fetchedResultsController sections] objectAtIndex:section];
    return [sectionInfo numberOfObjects];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    id <NSFetchedResultsSectionInfo> sectionInfo = [[_fetchedResultsController sections] objectAtIndex:section];
    return [sectionInfo name];
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView
{
    return [_fetchedResultsController sectionIndexTitles];
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index
{
    return [_fetchedResultsController sectionForSectionIndexTitle:title atIndex:index];
}

- (void)configureCell:(UITableViewCell*)cell atIndexPath:(NSIndexPath*)indexPath
{
    if (!cell.accessoryView) {
        UILabel *distanceLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 60, 20)];
        distanceLabel.textAlignment = NSTextAlignmentRight;
        distanceLabel.font = [UIFont systemFontOfSize:12];
        distanceLabel.backgroundColor = [UIColor clearColor];
        distanceLabel.highlightedTextColor = [UIColor whiteColor];
        cell.accessoryView = distanceLabel;
    }
    
    Thread *thread = [_fetchedResultsController objectAtIndexPath:indexPath];

    UILabel *distanceLabel = (UILabel*) cell.accessoryView;
    double distance = 0.000621371 * thread.distance.doubleValue;
    distanceLabel.text = [NSString stringWithFormat:@"%.1f mi", distance];

    cell.detailTextLabel.text = thread.details;

    cell.textLabel.text = thread.name;
    if (thread.password.boolValue) {
        cell.textLabel.text = [@"\U0001f512 " stringByAppendingString:thread.name];
    }
    [cell.textLabel sizeToFit];
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MarkerCell"];
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    Thread *thread = [_fetchedResultsController objectAtIndexPath:indexPath];
    [self selectThread:thread];
}

#pragma mark - MKMapViewDelegate

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id <MKAnnotation>)annotation
{
    if ([annotation isKindOfClass:[MarkerAnnotation class]]) {
        static NSString *identifier = @"Marker";
        MKPinAnnotationView *annotationView = (MKPinAnnotationView *) [_mapView dequeueReusableAnnotationViewWithIdentifier:identifier];
        if (annotationView == nil) {
            annotationView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:identifier];
            annotationView.animatesDrop = YES;
            annotationView.enabled = YES;
            annotationView.canShowCallout = YES;
            annotationView.rightCalloutAccessoryView = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
        } else {
            annotationView.annotation = annotation;
        }
        return annotationView;
    }
    return nil;
}

- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view calloutAccessoryControlTapped:(UIControl *)control
{
    MarkerAnnotation *annotation = view.annotation;
    [self selectThread:annotation.thread];
}

#pragma mark - NSFetchedResultsControllerDelegate

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
    
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex]
                          withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex]
                          withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}


- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    
    UITableView *tableView = self.tableView;
    
    switch(type) {
            
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath]
                             withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                             withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [self configureCell:[tableView cellForRowAtIndexPath:indexPath]
                    atIndexPath:indexPath];
            break;
            
        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                             withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath]
                             withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}


- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView endUpdates];
}

@end
