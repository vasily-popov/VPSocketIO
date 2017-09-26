//
//  VPSocketEngine+EnginePollable.h
//  VPSocketIO
//
//  Created by Vasily Popov on 9/26/17.
//  Copyright © 2017 Vasily Popov. All rights reserved.
//

#import "VPSocketEngine.h"
#import "VPSocketEngine+Private.h"

@interface VPSocketEngine (EnginePollable)

- (void) doPoll;
- (void) stopPolling;
- (void) doLongPoll:(NSURLRequest *)request;
- (void) disconnectPolling;

- (void)sendPollMessage:(NSString *)message withType:(VPSocketEnginePacketType)type withData:(NSArray *)array;
@end
