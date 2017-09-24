//
//  SocketAckManager.m
//  VPSocketIO
//
//  Created by Vasily Popov on 9/20/17.
//  Copyright © 2017 Vasily Popov. All rights reserved.
//

#import "VPSocketAckManager.h"

@interface VPSocketAckManager()
{
    NSMutableSet<VPSocketAck*>*acks;
    dispatch_semaphore_t ackSemaphore;
}

@end

@implementation VPSocketAckManager

-(instancetype)init
{
    self = [super init];
    if(self) {
        acks = [NSMutableSet set];
        ackSemaphore = dispatch_semaphore_create(0);
    }
    return self;
}
-(void)addAck:(int)ack callback:(VPAckCallback)callback
{
    [acks addObject:[[VPSocketAck alloc] initWithAck:ack andCallBack:callback]];
}
-(void)executeAck:(int)ack withItems:(NSArray*)items onQueue:(dispatch_queue_t)queue
{
    VPSocketAck *socketAck = [self removeAckWithId:ack];
    dispatch_async(queue, ^{
        if(socketAck && socketAck.callback) {
            socketAck.callback(items);
        }
    });
    
}
-(void)timeoutAck:(int)ack onQueue:(dispatch_queue_t)queue
{
    VPSocketAck *socketAck = [self removeAckWithId:ack];
    dispatch_async(queue, ^{
        if(socketAck && socketAck.callback) {
            socketAck.callback(@[@"NO ACK"]);
        }
    });
}

-(VPSocketAck*)removeAckWithId:(int)ack {
    
    dispatch_semaphore_wait(ackSemaphore,DISPATCH_TIME_FOREVER);
    VPSocketAck *socketAck = nil;
    for (VPSocketAck *vpack in acks) {
        if(vpack.ack == ack) {
            socketAck = vpack;
        }
    }
    [acks removeObject:socketAck];
    dispatch_semaphore_signal(ackSemaphore);
    return socketAck;
}

@end


@implementation VPSocketAck

-(instancetype)initWithAck:(int)ack andCallBack:(VPAckCallback)callback
{
    self = [super init];
    if(self) {
        self.ack = ack;
        self.callback = callback;
    }
    return self;
}

- (NSUInteger)hash
{
    return _ack;
}

@end

