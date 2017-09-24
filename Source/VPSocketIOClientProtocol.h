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
#import "VPSocketAckManager.h"

typedef enum : NSUInteger {
    VPSocketIOClientStatusNotConnected = 0x1,
    VPSocketIOClientStatusDisconnected = 0x2,
    VPSocketIOClientStatusConnecting = 0x3,
    VPSocketIOClientStatusConnected= 0x4
} VPSocketIOClientStatus;

typedef enum : NSUInteger {
    /// Called when the client connects. This is also called on a successful reconnection. A connect event gets one
    VPSocketClientEventConnect = 0x100,
    /// Called when the socket has disconnected and will not attempt to try to reconnect.
    VPSocketClientEventDisconnect =  0x101,
    /// Called when an error occurs.
    VPSocketClientEventError =  0x102,
    /// Called when the client begins the reconnection process.
    VPSocketClientEventReconnect =  0x103,
    /// Called each time the client tries to reconnect to the server.
    VPSocketClientEventReconnectAttempt =  0x104,
    /// Called every time there is a change in the client's status.
    VPSocketClientEventStatusChange =  0x105,
} VPSocketClientEvent;

@protocol VPSocketIOClientProtocol <NSObject>

@required

@property (nonatomic, strong) VPSocketAckManager *ackHandlers;
@property (nonatomic, strong, readonly) dispatch_queue_t handleQueue;

-(void)handleClientEvent:(NSString*)event withData:(NSArray*)data;
-(void)joinNamespace:(NSString*)namespace;

-(void)emit:(NSString*)event items:(NSArray*)items;
-(void)emitAck:(int)ack withItems:(NSArray*)items;


@end

#endif
