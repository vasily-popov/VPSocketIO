//
//  VPSocketLogger.h
//  VPSocketIO
//
//  Created by Vasily Popov on 9/26/17.
//  Copyright © 2017 Vasily Popov. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface VPSocketLogger:NSObject

@property (nonatomic) BOOL log;

-(void) log:(NSString*)message type:(NSString*)type;
-(void) error:(NSString*)message type:(NSString*)type;

@end
