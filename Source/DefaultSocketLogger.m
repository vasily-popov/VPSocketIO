//
//  DefaultSocketLogger.m
//  VPSocketIO
//
//  Created by Vasily Popov on 9/23/17.
//  Copyright © 2017 Vasily Popov. All rights reserved.
//

#import "DefaultSocketLogger.h"


@implementation SocketLogger

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.log = NO;
    }
    return self;
}

-(void) log:(NSString*)message type:(NSString*)type
{
    [self printLog:@"LOG" message:message type:type];
}
-(void) error:(NSString*)message type:(NSString*)type
{
    [self printLog:@"ERROR" message:message type:type];
}

-(void) printLog:(NSString*)logType message:(NSString*)message type:(NSString*)type
{
    if(_log) {
        NSLog(@"%@ %@: %@", logType, type, message);
    }
    
}

@end

@implementation DefaultSocketLogger

static SocketLogger *logInstance;

+(void)setLogger:(SocketLogger*)newLogger {
    logInstance = newLogger;
}

+(SocketLogger*)logger {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        logInstance = [SocketLogger new];
    });
    return logInstance;
    
}

@end
