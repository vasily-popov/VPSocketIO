//
//  VPSocketIOClient.h
//  VPSocketIO
//
//  Created by Vasily Popov on 9/19/17.
//  Copyright © 2017 Vasily Popov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VPSocketAckEmitter.h"
#import "VPSocketIOUtils.h"
#import "VPSocketIOClientProtocol.h"

@interface VPSocketIOClient : NSObject<VPSocketIOClientProtocol>

@property (nonatomic, readonly) VPSocketIOClientStatus status;
@property (nonatomic) BOOL forceNew;
@property (nonatomic, strong, readonly) NSMutableDictionary *config;
@property (nonatomic) BOOL reconnects;
@property (nonatomic) int reconnectWait;
@property (nonatomic, strong, readonly) NSString *ssid;
@property (nonatomic, strong, readonly) NSURL *socketURL;

@property (nonatomic, strong, readonly) dispatch_queue_t handleQueue;
@property (nonatomic, strong, readonly) NSString* nsp;

-(instancetype)init:(NSURL*)socketURL withConfig:(NSDictionary*)config;
-(void) connect;
-(void) connectWithTimeoutAfter:(double)timeout withHandler:(VPSocketHandler)handler;
-(void) disconnect;
-(void) reconnect;
-(void) removeAllHandlers;


-(OnAckCallback*) emitWithAck:(NSString*)event items:(NSArray*)items;

-(NSUUID*) on:(NSString*)event callback:(VPSocketNormalCallback) callback;
-(NSUUID*) once:(NSString*)event callback:(VPSocketNormalCallback) callback;
-(void) onAny:(VPSocketAnyEventHandler)handler;

@end
