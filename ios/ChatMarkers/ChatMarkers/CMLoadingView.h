//
//  CMLoadingView.h
//  ChatMarkers
//
//  Created by James McEvoy on 7/26/13.
//  Copyright (c) 2013 Chat Markers LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CMLoadingView : UIView

+ (CMLoadingView*)showInView:(UIView*)view message:(NSString*)message;
- (void)dismiss;

@end
