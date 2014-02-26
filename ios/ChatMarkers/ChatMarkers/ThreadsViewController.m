//
//  ThreadsViewController.m
//  ChatMarkers
//
//  Created by James McEvoy on 7/26/13.
//  Copyright (c) 2013 Chat Markers LLC. All rights reserved.
//

#import "AppDelegate.h"
#import "CMAlertView.h"
#import "MessagesViewController.h"
#import "Server.h"
#import "Thread.h"
#import "ThreadsViewController.h"

@interface ThreadsViewController () <UITableViewDelegate,UITableViewDataSource,NSFetchedResultsControllerDelegate>

@property(nonatomic,weak) IBOutlet UITableView *tableView;

@end

@implementation ThreadsViewController {
    NSManagedObjectContext *_managedObjectContext;
    NSFetchedResultsController *_fetchedResultsController;
    NSDateFormatter *_dateDisplayFormatter;
    NSDateFormatter *_timeDisplayFormatter;
    UILabel *_refreshLabel;
    UIView *_refreshView;
    BOOL _refreshing;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _refreshView = [[UIView alloc] initWithFrame:CGRectMake(0, -60, self.view.frame.size.width, 60)];
    _refreshLabel = [[UILabel alloc] initWithFrame:_refreshView.bounds];
    _refreshLabel.text = @"Pull down to refresh.";
    _refreshLabel.textAlignment = NSTextAlignmentCenter;
    _refreshLabel.font = [UIFont boldSystemFontOfSize:16];
    [_refreshView addSubview:_refreshLabel];
    [_tableView addSubview:_refreshView];
    
    _dateDisplayFormatter = [[NSDateFormatter alloc] init];
    _dateDisplayFormatter.dateStyle = NSDateFormatterShortStyle;
    
    _timeDisplayFormatter = [[NSDateFormatter alloc] init];
    _timeDisplayFormatter.timeStyle = NSDateFormatterShortStyle;
    
    [[Server sharedInstance] downloadThreadsWithCompletionHandler:nil];
    
    _managedObjectContext = [AppDelegate sharedInstance].managedObjectContext;
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass([Thread class])];
    request.predicate = [NSPredicate predicateWithFormat:@"me != NULL"];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"time" ascending:NO]];
    
    _fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:request managedObjectContext:_managedObjectContext sectionNameKeyPath:nil cacheName:nil];
    _fetchedResultsController.delegate = self;
    
    NSError *error = nil;
    if (![_fetchedResultsController performFetch:&error]) {
        NSLog(@"Unable to perform fetch: %@", error);
    }
    [self.tableView reloadData];
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

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ThreadCell"];
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
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
        UILabel *timeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 60, 20)];
        timeLabel.textAlignment = NSTextAlignmentRight;
        timeLabel.font = [UIFont systemFontOfSize:12];
        timeLabel.backgroundColor = [UIColor clearColor];
        timeLabel.highlightedTextColor = [UIColor whiteColor];
        cell.accessoryView = timeLabel;
    }
    
    if (indexPath.section < [self numberOfSectionsInTableView:self.tableView] && indexPath.row < [self tableView:self.tableView numberOfRowsInSection:indexPath.section]) {
        Thread *thread = [_fetchedResultsController objectAtIndexPath:indexPath];
        cell.textLabel.text = thread.name;
        cell.textLabel.backgroundColor = [UIColor clearColor];
        
        UILabel *timeLabel = (UILabel*) cell.accessoryView;
        NSDate *time = [[Server sharedInstance] parseDate:thread.time];
        if (- [time timeIntervalSinceNow] < 24 * 60 * 60) {
            timeLabel.text = [_timeDisplayFormatter stringFromDate:time];
        }
        else {
            timeLabel.text = [_dateDisplayFormatter stringFromDate:time];
        }                
        cell.detailTextLabel.text = thread.details;
        
        if (thread.latitude && thread.longitude) {
            //cell.imageView.image = [UIImage imageNamed:@"icn_chat"];
        }
        else {
            cell.imageView.image = nil;
        }
    }
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    Thread *thread = [_fetchedResultsController objectAtIndexPath:indexPath];
    if (thread.unread.boolValue) {
        cell.backgroundColor = [UIColor colorWithRed:0.9 green:1.0 blue:0.9 alpha:1.0];
    }
    else {
        cell.backgroundColor = [UIColor clearColor];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    Thread *thread = [_fetchedResultsController objectAtIndexPath:indexPath];
    [self performSegueWithIdentifier:@"MessagesSegue" sender:thread];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.destinationViewController isKindOfClass:[MessagesViewController class]]) {
        MessagesViewController *vc = segue.destinationViewController;
        vc.thread = sender;
    }
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

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (_refreshing) return;
    
    if (scrollView.contentOffset.y < _refreshView.frame.origin.y) {
        _refreshLabel.text = @"Release to refresh.";
    }
    else {
        _refreshLabel.text = @"Pull down to refresh.";
    }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (scrollView.contentOffset.y < _refreshView.frame.origin.y) {
        _refreshing = YES;
        _refreshLabel.text = @"Refreshing...";
        scrollView.contentInset = UIEdgeInsetsMake(_refreshView.frame.size.height, 0, 0, 0);
        
        [[Server sharedInstance] downloadThreadsWithCompletionHandler:^(NSError *error) {
            if (error) {
                [[CMAlertView alertWithServerError:error reponse:nil] show];
            }
            _refreshing = NO;
            scrollView.contentInset = UIEdgeInsetsZero;
            [self scrollViewDidScroll:scrollView];
        }];
    }
}

@end
