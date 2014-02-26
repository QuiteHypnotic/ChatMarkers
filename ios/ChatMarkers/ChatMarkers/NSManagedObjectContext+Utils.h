//
//  NSManagedObjectContext+Utils.h
//  ChatMarkers
//
//  Created by James McEvoy on 7/26/13.
//  Copyright (c) 2013 Chat Markers LLC. All rights reserved.
//

#import <CoreData/CoreData.h>

@interface NSManagedObjectContext (Utils)

- (id)upsertClass:(Class)cls column:(NSString*)column value:(id)value;

@end
