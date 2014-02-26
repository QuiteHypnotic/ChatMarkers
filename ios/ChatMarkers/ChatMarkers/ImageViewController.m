//
//  ImageViewController.m
//  ChatMarkers
//
//  Created by James McEvoy on 7/27/13.
//  Copyright (c) 2013 Chat Markers LLC. All rights reserved.
//

#import "ImageViewController.h"

@interface ImageViewController () <UIScrollViewDelegate>

@property(nonatomic,weak) IBOutlet UIScrollView *scrollView;

- (IBAction)dismiss;
- (IBAction)share;

@end

@implementation ImageViewController {
    UIImageView *_imageView;
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    if (!_imageView) {
        _imageView = [[UIImageView alloc] initWithImage:self.image];
        _imageView.frame = self.scrollView.bounds;
        _imageView.contentMode = UIViewContentModeScaleAspectFit;
        _imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.scrollView addSubview:_imageView];
        self.scrollView.contentSize = _imageView.frame.size;
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationSlide];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationSlide];
    [super viewWillDisappear:animated];
}

- (IBAction)dismiss
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)share
{
    UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:@[@"Look what I found on Chat Markers!", self.image, @"http://chatmarkers.com"] applicationActivities:nil];
    [self presentViewController:activityController animated:YES completion:nil];
}

#pragma mark - UIScrollViewDelegate

- (UIView*)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
    return _imageView;
}

@end
