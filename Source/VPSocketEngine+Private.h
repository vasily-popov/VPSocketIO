//
//  VPSocketEngine+Private.h
//  VPSocketIO
//
//  Created by Vasily Popov on 9/26/17.
//  Copyright © 2017 Vasily Popov. All rights reserved.
//

#import "VPSocketEngine.h"
#import "JFRWebSocket.h"

typedef enum : NSUInteger{
    VPSocketEnginePacketTypeOpen = 0x0,
    VPSocketEnginePacketTypeClose = 0x1,
    VPSocketEnginePacketTypePing = 0x2,
    VPSocketEnginePacketTypePong = 0x3,
    VPSocketEnginePacketTypeMessage = 0x4,
    VPSocketEnginePacketTypeUpgrade = 0x5,
    VPSocketEnginePacketTypeNoop = 0x6,
} VPSocketEnginePacketType;

@interface VPSocketEngine ()

@property (nonatomic, strong, readonly) NSDictionary *stringEnginePacketType;
@property (nonatomic, readonly) BOOL invalidated;
@property (nonatomic, strong) NSMutableArray<NSString*>* postWait;
@property (nonatomic, strong, readonly) NSURLSession *session;
@property (nonatomic) BOOL waitingForPoll;
@property (nonatomic) BOOL waitingForPost;
@property (nonatomic, strong) NSString* sid;
@property (nonatomic, strong) NSURL *urlPolling;
@property (nonatomic) BOOL websocket;
@property (nonatomic, strong) JFRWebSocket* ws;
@property (nonatomic) BOOL fastUpgrade;
@property (nonatomic) BOOL polling;
@property (nonatomic) BOOL forcePolling;
@property (nonatomic) BOOL forceWebsockets;
@property (nonatomic) BOOL probing;


- (void)didError:(NSString*)reason;
- (void)doFastUpgrade;
- (void)addHeaders:(NSMutableURLRequest *)request;
- (void)parseEngineMessage:(NSString*)message;
- (void)flushWaitingForPostToWebSocket;
@end
