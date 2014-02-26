//
//  MessagesViewController.h
//  ChatMarkers
//
//  Created by James McEvoy on 7/26/13.
//  Copyright (c) 2013 Chat Markers LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BaseViewController.h"
#import "Thread.h"

@interface MessagesViewController : BaseViewController

@property(nonatomic) Thread *thread;

@end
