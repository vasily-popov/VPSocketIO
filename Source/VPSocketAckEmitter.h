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
-(void)emitWith:(NSArray*) items;

@end

