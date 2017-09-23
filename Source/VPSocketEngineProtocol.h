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
    VPSocketEnginePacketTypeOpen = 0x1,
    VPSocketEnginePacketTypeClose = 0x2,
    VPSocketEnginePacketTypePing = 0x3,
    VPSocketEnginePacketTypePong = 0x4,
    VPSocketEnginePacketTypeMessage = 0x5,
    VPSocketEnginePacketTypeUpgrade = 0x6,
    VPSocketEnginePacketTypeNoop = 0x7,
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

@property (nonatomic, strong) NSDictionary* connectParams;
@property (nonatomic, strong, readonly) NSArray<NSHTTPCookie*>* cookies;
@property (nonatomic, strong, readonly) dispatch_queue_t engineQueue;

@property (nonatomic, strong, readonly) NSDictionary* extraHeaders;

@property (nonatomic, readonly) BOOL fastUpgrade;
@property (nonatomic, readonly) BOOL forcePolling;
@property (nonatomic, readonly) BOOL forceWebsockets;
@property (nonatomic, readonly) BOOL polling;
@property (nonatomic, readonly) BOOL probing;
@property (nonatomic, strong, readonly) NSString* sid;
@property (nonatomic, strong, readonly) NSString* socketPath;
@property (nonatomic, strong, readonly) NSURL* urlPolling;

@property (nonatomic, strong, readonly) NSURL* urlWebSocket;
/// If `true`, then the engine is currently in WebSockets mode.
@property (nonatomic, readonly) BOOL websocket;
@property (nonatomic, strong, readonly) JFRWebSocket* ws;

/// Starts the connection to the server.
-(void)connect;
/// Called when an error happens during execution. Causes a disconnection.
-(void)didError:(NSString*)reason;
/// Disconnects from the server.
-(void)disconnect:(NSString*)reason;
/// Called to switch from HTTP long-polling to WebSockets. After calling this method the engine will be in
/// WebSocket mode.
///
/// **You shouldn't call this directly**
-(void)doFastUpgrade;
/// Causes any packets that were waiting for POSTing to be sent through the WebSocket. This happens because when
/// the engine is attempting to upgrade to WebSocket it does not do any POSTing.
///
/// **You shouldn't call this directly**
-(void)flushWaitingForPostToWebSocket;
/// Parses raw binary received from engine.io.
-(void)parseEngineData:(NSData*)data;
/// Parses a raw engine.io packet.
-(void)parseEngineMessage:(NSString*) message;


/// Writes a message to engine.io, independent of transport.
-(void)write:(NSString*)msg withType:(VPSocketEnginePacketType)type withData:(NSArray<NSData*>*)data;


-(NSURL*) urlPollingWithSid;
-(NSURL*) urlWebSocketWithSid;

-(void)addHeaders:(NSMutableURLRequest *)request;

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
-(void)sendPollMessage:(NSString*)message withType:(VPSocketEnginePacketType)type withData:(NSArray*)data;


-(NSURLRequest*)createRequestForPostWithPostWait;

-(void)doRequest:(NSURLRequest*)request withCallback:(VPEngineResponseCallBack)callback;
-(void)doLongPoll:(NSURLRequest*)request;
-(void)flushWaitingForPost;
-(void)parsePollingMessage:(NSString*)str;

@end

@protocol VPSocketEngineWebsocketProtocol <NSObject>

-(void) sendWebSocketMessage:(NSString*)str withType:(VPSocketEnginePacketType)type withData:(NSArray*)data;
-(void) probeWebSocket;


@end

#endif

