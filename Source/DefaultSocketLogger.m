//
//  DefaultSocketLogger.m
//  VPSocketIO
//
//  Created by Vasily Popov on 9/23/17.
//  Copyright © 2017 Vasily Popov. All rights reserved.
//

#import "DefaultSocketLogger.h"

@implementation DefaultSocketLogger

static VPSocketLogger *logInstance;

+(void)setLogger:(VPSocketLogger*)newLogger {
    logInstance = newLogger;
}

+(VPSocketLogger*)logger {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        logInstance = [VPSocketLogger new];
    });
    return logInstance;
    
}

@end
