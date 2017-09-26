//
//  VPSocketIOClientProtocol.h
//  VPSocketIO
//
//  Created by Vasily Popov on 9/19/17.
//  Copyright © 2017 Vasily Popov. All rights reserved.
//

#ifndef VPSocketIOClientProtocol_H
#define VPSocketIOClientProtocol_H

#import <Foundation/Foundation.h>
@class VPSocketAckManager;
@class VPSocketAckEmitter;

typedef void (^VPScoketAckArrayCallback)(NSArray*array);
typedef void (^VPSocketOnEventCallback)(NSArray*array, VPSocketAckEmitter*emitter);

@protocol VPSocketIOClientProtocol <NSObject>

@required

@property (nonatomic, strong) VPSocketAckManager *ackHandlers;
@property (nonatomic, strong, readonly) dispatch_queue_t handleQueue;

-(void)emit:(NSString*)event items:(NSArray*)items;
-(void)emitAck:(int)ack withItems:(NSArray*)items;


@end

#endif
