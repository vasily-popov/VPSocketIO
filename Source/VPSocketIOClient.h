//
//  VPSocketIOClient.h
//  VPSocketIO
//
//  Created by Vasily Popov on 9/19/17.
//  Copyright © 2017 Vasily Popov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VPSocketAnyEvent.h"
#import "VPSocketOnAckCallback.h"
#import "VPSocketIOClientProtocol.h"

typedef enum : NSUInteger {
    VPSocketIOClientStatusNotConnected = 0x1,
    VPSocketIOClientStatusDisconnected = 0x2,
    VPSocketIOClientStatusConnecting = 0x3,
    VPSocketIOClientStatusOpened = 0x4,
    VPSocketIOClientStatusConnected = 0x5
} VPSocketIOClientStatus;


extern NSString *const kSocketEventConnect;
extern NSString *const kSocketEventDisconnect;
extern NSString *const kSocketEventError;
extern NSString *const kSocketEventReconnect;
extern NSString *const kSocketEventReconnectAttempt;
extern NSString *const kSocketEventStatusChange;


typedef void (^VPSocketIOVoidHandler)(void);
typedef void (^VPSocketAnyEventHandler)(VPSocketAnyEvent*event);

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
-(void) connectWithTimeoutAfter:(double)timeout withHandler:(VPSocketIOVoidHandler)handler;
-(void) disconnect;
-(void) reconnect;
-(void) removeAllHandlers;

-(VPSocketOnAckCallback*) emitWithAck:(NSString*)event items:(NSArray*)items;

-(NSUUID*) on:(NSString*)event callback:(VPSocketOnEventCallback) callback;
-(NSUUID*) once:(NSString*)event callback:(VPSocketOnEventCallback) callback;
-(void) onAny:(VPSocketAnyEventHandler)handler;
-(void) off:(NSString*) event;

@end
