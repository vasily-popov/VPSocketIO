//
//  DefaultSocketLogger.h
//  VPSocketIO
//
//  Created by Vasily Popov on 9/23/17.
//  Copyright © 2017 Vasily Popov. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SocketLogger:NSObject

@property (nonatomic) BOOL log;

-(void) log:(NSString*)message type:(NSString*)type;
-(void) error:(NSString*)message type:(NSString*)type;

@end

@interface DefaultSocketLogger:NSObject

@property (class) SocketLogger *logger;

@end
