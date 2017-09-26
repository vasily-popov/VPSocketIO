//
//  VPSocketEngineProtocol.h
//  VPSocketIO
//
//  Created by Vasily Popov on 9/19/17.
//  Copyright © 2017 Vasily Popov. All rights reserved.
//

#ifndef VPSocketEngineProtocol_H
#define VPSocketEngineProtocol_H

#import <Foundation/Foundation.h>
#import <Jetfire/Jetfire.h>

typedef enum : NSUInteger{
    VPSocketEnginePacketTypeOpen = 0x0,
    VPSocketEnginePacketTypeClose = 0x1,
    VPSocketEnginePacketTypePing = 0x2,
    VPSocketEnginePacketTypePong = 0x3,
    VPSocketEnginePacketTypeMessage = 0x4,
    VPSocketEnginePacketTypeUpgrade = 0x5,
    VPSocketEnginePacketTypeNoop = 0x6,
} VPSocketEnginePacketType;

typedef void (^VPEngineResponseCallBack)(NSData* data, NSURLResponse*response, NSError*error);

@protocol VPSocketEngineClient <NSObject>

@required

/// Called when the engine errors.
-(void)engineDidError:(NSString*)reason;
/// Called when the engine opens.
-(void)engineDidOpen:(NSString*)reason;
/// Called when the engine closes.
-(void)engineDidClose:(NSString*)reason;
/// Called when the engine has a message that must be parsed.
-(void)parseEngineMessage:(NSString*)msg;
/// Called when the engine receives binary data.
-(void)parseEngineBinaryData:(NSData*)data;

@end


@protocol VPSocketEngineProtocol <NSObject>

@required

@property (nonatomic, strong) id<VPSocketEngineClient> client;
@property (nonatomic, readonly) BOOL closed;
@property (nonatomic, readonly) BOOL connected;

@property (nonatomic, strong, readonly) dispatch_queue_t engineQueue;

@property (nonatomic, readonly) BOOL fastUpgrade;
@property (nonatomic, readonly) BOOL forcePolling;
@property (nonatomic, readonly) BOOL forceWebsockets;
@property (nonatomic, readonly) BOOL polling;
@property (nonatomic, readonly) BOOL probing;
@property (nonatomic, strong, readonly) NSString* sid;
/// If `true`, then the engine is currently in WebSockets mode.
@property (nonatomic, readonly) BOOL websocket;
@property (nonatomic, strong, readonly) JFRWebSocket* ws;

/// Starts the connection to the server.
-(void)connect;
/// Disconnects from the server.
-(void)disconnect:(NSString*)reason;

-(void)send:(NSString*)msg withData:(NSArray<NSData*>*) data;

@end


@protocol VPSocketEnginePollableProtocol <NSObject>


@property (nonatomic, readonly) BOOL invalidated;
@property (nonatomic, strong, readonly) NSArray<NSString*>* postWait;
@property (nonatomic, strong, readonly) NSURLSession *session;
@property (nonatomic) BOOL waitingForPoll;
@property (nonatomic) BOOL waitingForPost;


-(void)doPoll;
-(void)stopPolling;


-(void)doRequest:(NSURLRequest*)request withCallback:(VPEngineResponseCallBack)callback;

@end

#endif

