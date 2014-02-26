//
//  NSManagedObjectContext+Utils.m
//  ChatMarkers
//
//  Created by James McEvoy on 7/26/13.
//  Copyright (c) 2013 Chat Markers LLC. All rights reserved.
//

#import "NSManagedObjectContext+Utils.h"

@implementation NSManagedObjectContext (Utils)


- (id)upsertClass:(Class)cls column:(NSString*)column value:(id)value;
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass(cls)];
    request.predicate = [NSPredicate predicateWithFormat:[column stringByAppendingString:@" == %@"], value];
    
    NSError *error = nil;
    NSArray *results = [self executeFetchRequest:request error:&error];
    if (error) {
        NSLog(@"Unable to fetch results: %@", error);
    }
    
    if (results.count) {
        return [results lastObject];
    }
    
    NSManagedObjectContext *result = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass(cls) inManagedObjectContext:self];
    [result setValue:value forKey:column];
    return result;
}

@end
