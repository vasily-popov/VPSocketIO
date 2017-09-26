//
//  VPSocketAckEmitter.m
//  VPSocketIO
//
//  Created by Vasily Popov on 9/19/17.
//  Copyright © 2017 Vasily Popov. All rights reserved.
//

#import "VPSocketAckEmitter.h"

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


-(void)emitWith:(NSArray*) items {
    if(_ackNum != -1) {
        [_socket emitAck:_ackNum withItems:items];
    }
}

@end

