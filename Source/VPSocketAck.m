//
//  VPSocketAck.m
//  VPSocketIO
//
//  Created by Vasily Popov on 9/26/17.
//  Copyright © 2017 Vasily Popov. All rights reserved.
//

#import "VPSocketAck.h"

@implementation VPSocketAck

-(instancetype)initWithAck:(int)ack andCallBack:(VPScoketAckArrayCallback)callback
{
    self = [super init];
    if(self) {
        _ack = ack;
        _callback = callback;
    }
    return self;
}

- (NSUInteger)hash
{
    return _ack & 0x0F;
}

@end
