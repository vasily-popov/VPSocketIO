//
//  VPSocketAckEmitter.m
//  VPSocketIO
//
//  Created by Vasily Popov on 9/19/17.
//  Copyright © 2017 Vasily Popov. All rights reserved.
//

#import "VPSocketAckEmitter.h"
#import "VPSocketIOClient.h"
#import "VPSocketIOUtils.h"


@interface VPSocketAckEmitter()

@property (nonatomic, strong) id<VPSocketIOClientProtocol> socket;
@property (nonatomic) int ackNum;

@end

@implementation VPSocketAckEmitter

-(instancetype)initWithSocket:(id<VPSocketIOClientProtocol>)socket ackNum:(int)ack
{
    self = [super init];
    if(self) {
        self.socket = socket;
        self.ackNum = ack;
    }
    return self;
}


-(void)with:(NSArray*) items {
    if(_ackNum != -1) {
        [_socket emitAck:_ackNum withItems:items];
    }
}

@end

@interface OnAckCallback()

@property (nonatomic, weak) id<VPSocketIOClientProtocol> socket;
@property (nonatomic, strong) NSArray* items;
@property (nonatomic) int ackNum;

@end

@implementation OnAckCallback

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


-(void)timingOutAfter:(double)seconds callback:(VPAckCallback)callback {
    
    if (self.socket != nil && _ackNum != -1) {
#warning TODO
        //socket.ackHandlers.addAck(ackNumber, callback: callback)
        //socket._emit(items, ack: ackNumber)
        
        if(seconds >0 ) {
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)), self.socket.handleQueue, ^{
#warning TODO
                //self.socket.ackHandlers.timeoutAck(self.ackNum, onQueue: self.socket.handleQueue);
            });
            
            
        }
    }
}

@end

