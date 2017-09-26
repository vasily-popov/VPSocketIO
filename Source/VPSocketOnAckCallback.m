//
//  VPSocketOnAckCallback.m
//  VPSocketIO
//
//  Created by Vasily Popov on 9/26/17.
//  Copyright © 2017 Vasily Popov. All rights reserved.
//

#import "VPSocketOnAckCallback.h"
#import "VPSocketAckManager.h"

@interface VPSocketOnAckCallback()

@property (nonatomic, weak) id<VPSocketIOClientProtocol> socket;
@property (nonatomic, strong) NSArray* items;
@property (nonatomic) int ackNum;

@end

@implementation VPSocketOnAckCallback

-(instancetype)initAck:(int)ack items:(NSArray*)items socket:(id<VPSocketIOClientProtocol>)socket
{
    self = [super init];
    if(self) {
        self.socket = socket;
        self.ackNum = ack;
        self.items = items;
    }
    return self;
}


-(void)timingOutAfter:(double)seconds callback:(VPScoketAckArrayCallback)callback {
    
    if (self.socket != nil && _ackNum != -1) {
        
        [self.socket.ackHandlers addAck:_ackNum callback:callback];
        [self.socket emitAck:_ackNum withItems:_items];
        if(seconds >0 ) {
            
            __weak typeof(self) weakSelf = self;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)), self.socket.handleQueue, ^
            {
                @autoreleasepool
                {
                    __strong typeof(self) strongSelf = weakSelf;
                    if(strongSelf) {
                        [strongSelf.socket.ackHandlers timeoutAck:strongSelf.ackNum
                                                          onQueue:strongSelf.socket.handleQueue];
                    }
                }
            });
        }
    }
}

@end
