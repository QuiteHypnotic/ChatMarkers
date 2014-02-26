//
//  MessagesViewController.m
//  ChatMarkers
//
//  Created by James McEvoy on 7/26/13.
//  Copyright (c) 2013 Chat Markers LLC. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "AppDelegate.h"
#import "CMAlertView.h"
#import "CMLoadingView.h"
#import "ImageViewController.h"
#import "Message.h"
#import "MessagesViewController.h"
#import "MessageTableViewCell.h"
#import "Server.h"
#import "ThreadsViewController.h"
#import "User.h"

@interface MessagesViewController () <UITableViewDelegate,UITableViewDataSource,NSFetchedResultsControllerDelegate,UIGestureRecognizerDelegate,UIActionSheetDelegate,UIImagePickerControllerDelegate,UINavigationControllerDelegate>

@property(nonatomic,weak) IBOutlet UITableView *tableView;
@property(nonatomic,weak) IBOutlet UITextView *textView;
@property(nonatomic,weak) IBOutlet NSLayoutConstraint *bottomMarginConstraint;
@property(nonatomic,weak) IBOutlet NSLayoutConstraint *sendMessageHeightConstraint;

- (IBAction)sendMessage;

@end

@implementation MessagesViewController {
    NSManagedObjectContext *_managedObjectContext;
    NSFetchedResultsController *_fetchedResultsController;
    BOOL _keyboardShown;
    UIImageView *_selectedImageView;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[Server sharedInstance] downloadMessages:self.thread completionHandler:^(NSError *error) {
        if (error) {
            [[CMAlertView alertWithServerError:error reponse:nil] show];
        }
    }];
    
    if (self.thread.details) {
        UILabel *detailsLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, 280, 0)];
        detailsLabel.backgroundColor = [UIColor clearColor];
        detailsLabel.textColor = [UIColor whiteColor];
        detailsLabel.font = [UIFont systemFontOfSize:14];
        detailsLabel.text = self.thread.details;
        detailsLabel.numberOfLines = 0;
        detailsLabel.lineBreakMode = NSLineBreakByWordWrapping;
        CGSize size = [detailsLabel.text sizeWithFont:detailsLabel.font constrainedToSize:CGSizeMake(280, MAXFLOAT) lineBreakMode:detailsLabel.lineBreakMode];
        detailsLabel.frame = CGRectMake(20, 20, 280, size.height);
        
        UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, size.height + 40)];
        headerView.backgroundColor = [UIColor blackColor];
        [headerView addSubview:detailsLabel];
        self.tableView.tableHeaderView = headerView;
    }
            
    UIButton *backButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [backButton setImage:[UIImage imageNamed:@"btn_back"] forState:UIControlStateNormal];
    [backButton addTarget:self action:@selector(back) forControlEvents:UIControlEventTouchUpInside];
    backButton.frame = CGRectMake(0, 0, 40, 40);
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:backButton];
    
    UIBarButtonItem *cameraButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCamera target:self action:@selector(didSelectCamera)];
    self.navigationItem.rightBarButtonItem = cameraButton;
    
    if (!self.thread.me) {
        self.sendMessageHeightConstraint.constant = 0;
        
        UIBarButtonItem *subscribeButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(didSelectSubscribe)];
        self.navigationItem.rightBarButtonItem = subscribeButton;
    }
    
    self.title = self.thread.name;
    self.textView.layer.borderWidth = 1;
    self.textView.layer.borderColor = [UIColor lightGrayColor].CGColor;
    
    _managedObjectContext = self.thread.managedObjectContext;
    
    NSError *error = nil;
    self.thread.unread = @(NO);
    if (![_managedObjectContext save:&error]) {
        NSLog(@"Unable to mark thread as read: %@", error);
    }
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass([Message class])];
    request.predicate = [NSPredicate predicateWithFormat:@"thread == %@", self.thread];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"time" ascending:YES]];
    
    _fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:request managedObjectContext:_managedObjectContext sectionNameKeyPath:nil cacheName:nil];
    _fetchedResultsController.delegate = self;
    
    if (![_fetchedResultsController performFetch:&error]) {
        NSLog(@"Unable to perform fetch: %@", error);
    }
    [self.tableView reloadData];
    
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

- (void)viewDidLayoutSubviews
{
    [self scrollToBottom:NO];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.textView resignFirstResponder];
}

- (void)dismissKeyboard:(UITapGestureRecognizer*)gestureRecognizer
{
    if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
        [self.textView resignFirstResponder];
    }
}

- (void)back
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)didSelectSubscribe
{
    CMLoadingView *loadingView = [CMLoadingView showInView:self.navigationController.view message:nil];
    [[Server sharedInstance] subscribeThread:self.thread password:nil completionHandler:^(NSError *error) {
        [loadingView dismiss];
        
        if (error) {
            [[CMAlertView alertWithServerError:error reponse:nil] show];
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

- (void)didSelectCamera
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

- (void)scrollToBottom:(BOOL)animated
{
    CGRect rect = CGRectMake(0, self.tableView.contentSize.height - 1, 1, 1);
    [self.tableView scrollRectToVisible:rect animated:animated];
}

- (IBAction)sendMessage
{
    if (self.textView.text.length == 0) return;
    
    CMLoadingView *loadingView = [CMLoadingView showInView:self.textView.superview message:nil];
    
    void(^completionHandler)(NSDictionary*, NSError *) = ^(NSDictionary *response, NSError *error) {
        [loadingView dismiss];
        
        if (error) {
            [[CMAlertView alertWithServerError:error reponse:response] show];
            return;
        }
        
        Message *message = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([Message class]) inManagedObjectContext:_managedObjectContext];
        message.remoteId = response[@"id"];
        message.text = response[@"text"];
        message.time = response[@"created_time"];
        message.image = response[@"image"];
        message.thread = self.thread;
        message.user = self.thread.me;
        message.thread.time = message.time;
        
        self.textView.text = @"";
        [self scrollToBottom:YES];
        [_selectedImageView removeFromSuperview];
        self.textView.contentInset = UIEdgeInsetsMake(0, 0, 0, 0);
        
        if (![_managedObjectContext save:&error]) {
            NSLog(@"Unable to save sent message: %@", error);
        }
    };
    
    if (!_selectedImageView) {
        NSDictionary *body = @{@"text": self.textView.text};
        NSString *path = [NSString stringWithFormat:@"/threads/%@/messages", self.thread.remoteId];
        [[Server sharedInstance] executeMethod:@"POST" path:path body:body completionHandler:completionHandler];
    }
    else {
        NSString *path = [NSString stringWithFormat:@"/threads/%@/messages", self.thread.remoteId];
        NSDictionary *params = @{@"text": self.textView.text};
        NSData *data = UIImageJPEGRepresentation(_selectedImageView.image, 1.0);

        [[Server sharedInstance] uploadFilePath:path params:params filename:@"image" contentType:@"image/jpeg" data:data completionHandler:completionHandler];
    }
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
    
    [self scrollToBottom:YES];
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
    Message *message = [_fetchedResultsController objectAtIndexPath:indexPath];
    MessageTableViewCell *cell = nil;
    if (message.user == self.thread.me) {
        cell = (MessageTableViewCell*) [tableView dequeueReusableCellWithIdentifier:@"MessageCell"];
    }
    else {
        cell = (MessageTableViewCell*) [tableView dequeueReusableCellWithIdentifier:@"MessageCell"];
    }
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

- (void)configureCell:(MessageTableViewCell*)cell atIndexPath:(NSIndexPath*)indexPath
{
    if (indexPath.section < [self numberOfSectionsInTableView:self.tableView] && indexPath.row < [self tableView:self.tableView numberOfRowsInSection:indexPath.section]) {
        Message *message = [_fetchedResultsController objectAtIndexPath:indexPath];
        [cell setMessage:message];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    Message *message = [_fetchedResultsController objectAtIndexPath:indexPath];
    return [MessageTableViewCell heightForMessage:message];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    MessageTableViewCell *cell = (MessageTableViewCell*) [tableView cellForRowAtIndexPath:indexPath];
    UIImage *image = cell.image;
    if (image) {
        ImageViewController *vc = [self.storyboard instantiateViewControllerWithIdentifier:@"ImageViewController"];
        vc.image = image;
        [self presentViewController:vc animated:YES completion:nil];
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
            [self configureCell:(MessageTableViewCell*)[tableView cellForRowAtIndexPath:indexPath]
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
    [self scrollToBottom:YES];
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    return _keyboardShown;
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

    UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];
    float scale = MIN(800 / image.size.width, 800 / image.size.height);
    
    CGRect frame = CGRectMake(0, 0, scale * image.size.width, scale * image.size.height);
    UIGraphicsBeginImageContext(frame.size);
    [image drawInRect:frame];
    image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    if (_selectedImageView) {
        [_selectedImageView removeFromSuperview];
    }
    _selectedImageView = [[UIImageView alloc] initWithImage:image];
    _selectedImageView.contentMode = UIViewContentModeScaleAspectFit;
    _selectedImageView.frame = CGRectMake(10, -110, self.textView.frame.size.width - 20, 100);
    
    self.textView.contentInset = UIEdgeInsetsMake(_selectedImageView.frame.size.height + 20, 0, 0, 0);
    [self.textView addSubview:_selectedImageView];
}

@end
