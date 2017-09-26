//
//  NSString+VPSocketIO.h
//  VPSocketIO
//
//  Created by Vasily Popov on 9/23/17.
//  Copyright © 2017 Vasily Popov. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (VPSocketIO)

-(NSDictionary*)toDictionary;
-(NSString*)urlEncode;
-(NSArray*)toArray;

@end
