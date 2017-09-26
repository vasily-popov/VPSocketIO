//
//  NSString+VPSocketIO.m
//  VPSocketIO
//
//  Created by Vasily Popov on 9/23/17.
//  Copyright © 2017 Vasily Popov. All rights reserved.
//

#import "NSString+VPSocketIO.h"

@implementation NSString (VPSocketIO)

-(NSDictionary*)toDictionary {
    
    NSData *binData = [self dataUsingEncoding:NSUnicodeStringEncoding allowLossyConversion:NO];
    if(binData != nil) {
        NSError *error = nil;
        id json = [NSJSONSerialization JSONObjectWithData:binData options:NSJSONReadingAllowFragments error:&error];
        if(error == nil && [json isKindOfClass:[NSDictionary class]]) {
            return json;
        }
    }
    return nil;
}

-(NSString*)urlEncode
{
    return [self stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
}

-(NSArray*)toArray {
    
    NSData *binData = [self dataUsingEncoding:NSUnicodeStringEncoding allowLossyConversion:NO];
    if(binData != nil) {
        NSError *error = nil;
        id json = [NSJSONSerialization JSONObjectWithData:binData options:NSJSONReadingMutableContainers error:&error];
        if(error == nil && [json isKindOfClass:[NSArray class]]) {
            return json;
        }
    }
    return nil;
}

@end
