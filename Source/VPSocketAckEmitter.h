//
//  VPSocketAckEmitter.h
//  VPSocketIO
//
//  Created by Vasily Popov on 9/19/17.
//  Copyright © 2017 Vasily Popov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VPSocketIOClientProtocol.h"

@interface VPSocketAckEmitter : NSObject

-(instancetype)initWithSocket:(id<VPSocketIOClientProtocol>)socket ackNum:(int)ack;

@end


@interface OnAckCallback : NSObject

-(instancetype)initAck:(int)ack items:(NSArray*)items socket:(id<VPSocketIOClientProtocol>)socket;

@end
