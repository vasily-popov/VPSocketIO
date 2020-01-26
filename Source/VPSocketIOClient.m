//
//  VPSocketIOClient.m
//  VPSocketIO
//
//  Created by Vasily Popov on 9/19/17.
//  Copyright © 2017 Vasily Popov. All rights reserved.
//

#import "VPSocketIOClient.h"
#import "VPSocketAnyEvent.h"
#import "VPSocketEngineProtocol.h"
#import "VPSocketEngine.h"
#import "VPSocketPacket.h"
#import "VPSocketAckManager.h"
#import "DefaultSocketLogger.h"
#import "VPStringReader.h"
#import "NSString+VPSocketIO.h"

typedef enum : NSUInteger {
    /// Called when the client connects. This is also called on a successful reconnection. A connect event gets one
    VPSocketClientEventConnect = 0x0,
    /// Called when the socket has disconnected and will not attempt to try to reconnect.
    VPSocketClientEventDisconnect,
    /// Called when an error occurs.
    VPSocketClientEventError,
    /// Called when the client begins the reconnection process.
    VPSocketClientEventReconnect,
    /// Called each time the client tries to reconnect to the server.
    VPSocketClientEventReconnectAttempt,
    /// Called every time there is a change in the client's status.
    VPSocketClientEventStatusChange,
} VPSocketClientEvent;


NSString *const kSocketEventConnect            = @"connect";
NSString *const kSocketEventDisconnect         = @"disconnect";
NSString *const kSocketEventError              = @"error";
NSString *const kSocketEventReconnect          = @"reconnect";
NSString *const kSocketEventReconnectAttempt   = @"reconnectAttempt";
NSString *const kSocketEventStatusChange       = @"statusChange";


@interface VPSocketIOClient() <VPSocketEngineClient>
{
    int currentAck;
    int reconnectAttempts;
    int currentReconnectAttempt;
    BOOL reconnecting;
    VPSocketAnyEventHandler anyHandler;
    
    NSDictionary *eventStrings;
    NSDictionary *statusStrings;
}

@property (nonatomic, strong, readonly) NSString* logType;
@property (nonatomic, strong) id<VPSocketEngineProtocol> engine;
@property (nonatomic, strong) NSMutableArray<VPSocketEventHandler*>* handlers;
@property (nonatomic, strong) NSMutableArray<VPSocketPacket*>* waitingPackets;

@end

@implementation VPSocketIOClient

@synthesize ackHandlers;

-(instancetype)init:(NSURL*)socketURL withConfig:(NSDictionary*)config
{
    self = [super init];
    if (self) {
        [self setDefaultValues];
        _config = [config mutableCopy];
        _socketURL = socketURL;
        
        BOOL logEnabled = NO;
        
        if([socketURL.absoluteString hasPrefix:@"https://"])
        {
            [self.config setValue:@YES forKey:@"secure"];
        }
        
        for (NSString*key in self.config.allKeys)
        {
            id value = [self.config valueForKey:key];
            if([key isEqualToString:@"reconnects"])
            {
                _reconnects = [value boolValue];
            }
            if([key isEqualToString:@"reconnectAttempts"])
            {
                reconnectAttempts = [value intValue];
            }
            
            if([key isEqualToString:@"nsp"])
            {
                _nsp = value;
            }
            
            if([key isEqualToString:@"log"])
            {
                logEnabled = [value boolValue];
            }
            
            if([key isEqualToString:@"logger"])
            {
                [DefaultSocketLogger setLogger:value];
            }
            
            if([key isEqualToString:@"handleQueue"])
            {
                _handleQueue = value;
            }
            
            if([key isEqualToString:@"forceNew"])
            {
                _forceNew = [value boolValue];
            }

        }
        
        if([self.config objectForKey:@"path"] == nil) {
            [self.config setValue:@"/socket.io/" forKey:@"path"];
        }
        
        if(DefaultSocketLogger.logger == nil) {
            [DefaultSocketLogger setLogger:[VPSocketLogger new]];
        }
        
        DefaultSocketLogger.logger.log = logEnabled;
    }
    return self;
}

-(void) connect
{
    [self connectWithTimeoutAfter:0 withHandler:nil];
}

-(void) connectWithTimeoutAfter:(double)timeout withHandler:(VPSocketIOVoidHandler)handler
{
    if(_status != VPSocketIOClientStatusConnected) {
        self.status = VPSocketIOClientStatusConnecting;
        
        if (_engine == nil || _forceNew) {
            [self addEngine];
        }
        
        [_engine connect];
        
        if(timeout > 0)
        {
            __weak typeof(self) weakSelf = self;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC)), _handleQueue, ^
            {
                @autoreleasepool
                {
                    __strong typeof(self) strongSelf = weakSelf;
                    if(strongSelf != nil &&
                       (strongSelf.status == VPSocketIOClientStatusConnecting ||
                        strongSelf.status == VPSocketIOClientStatusNotConnected))
                    {
                        [strongSelf didDisconnect:@"Connection timeout"];
                        if(handler) {
                            handler();
                        }
                    }
                }
            });
        }
    }
    else {
        [DefaultSocketLogger.logger log:@"Tried connecting on an already connected socket" type:self.logType];
    }
}

/// Disconnects the socket.
-(void) disconnect
{
    [DefaultSocketLogger.logger log:@"Closing socket" type:self.logType];
    _reconnects = NO;
    [self didDisconnect:@"Disconnect"];
}

-(void)dealloc
{
    [DefaultSocketLogger.logger log:@"Client is being released" type:self.logType];
    [_engine disconnect: @"Client Deinit"];
    [DefaultSocketLogger setLogger:nil];
}


-(void)setDefaultValues {
    _status = VPSocketIOClientStatusNotConnected;
    _forceNew = NO;
    _handleQueue = dispatch_get_main_queue();
    _nsp = @"/";
    _reconnects = YES;
    _reconnectWait = 10;
    reconnecting = NO;
    currentAck = -1;
    reconnectAttempts = -1;
    currentReconnectAttempt = 0;
    ackHandlers = [[VPSocketAckManager alloc] init];
    _handlers = [[NSMutableArray alloc] init];
    _waitingPackets = [[NSMutableArray alloc] init];
    
    
    eventStrings =@{ @(VPSocketClientEventConnect)          : kSocketEventConnect,
                     @(VPSocketClientEventDisconnect)       : kSocketEventDisconnect,
                     @(VPSocketClientEventError)            : kSocketEventError,
                     @(VPSocketClientEventReconnect)        : kSocketEventReconnect,
                     @(VPSocketClientEventReconnectAttempt) : kSocketEventReconnectAttempt,
                     @(VPSocketClientEventStatusChange)     : kSocketEventStatusChange};
    
    
    statusStrings = @{ @(VPSocketIOClientStatusNotConnected) : @"notconnected",
                       @(VPSocketIOClientStatusDisconnected) : @"disconnected",
                       @(VPSocketIOClientStatusConnecting) : @"connecting",
                       @(VPSocketIOClientStatusOpened) : @"opened",
                       @(VPSocketIOClientStatusConnected) : @"connected"};
}

#pragma mark - property

-(void)setStatus:(VPSocketIOClientStatus)status
{
    _status = status;
    switch (status) {
        case VPSocketIOClientStatusConnected:
            reconnecting = NO;
            currentReconnectAttempt = 0;
            break;
            
        default:
            break;
    }
    [self handleClientEvent:eventStrings[@(VPSocketClientEventStatusChange)]
                   withData:@[statusStrings[@(status)]]];
    
}

-(NSString *)logType
{
    return @"VPSocketIOClient";
}
#pragma mark - private

-(void) addEngine
{
    [DefaultSocketLogger.logger log:@"Adding engine" type:self.logType];
    if(_engine)
    {
        [_engine syncResetClient];
    }
    _engine = [[VPSocketEngine alloc] initWithClient: self url: _socketURL options: _config];
}

-(VPSocketOnAckCallback*) createOnAck:(NSArray*)items
{
    currentAck += 1;
    return [[VPSocketOnAckCallback alloc] initAck:currentAck items:items socket:self];
}


-(void) didDisconnect:(NSString*)reason {
    
    if(_status != VPSocketIOClientStatusDisconnected) {
        
        [DefaultSocketLogger.logger log:[NSString stringWithFormat:@"Disconnected: %@", reason] type:self.logType];
        
        reconnecting = NO;
        self.status = VPSocketIOClientStatusDisconnected;
        
        // Make sure the engine is actually dead.
        [_engine disconnect:reason];
        [self handleClientEvent:eventStrings[@(VPSocketClientEventDisconnect)]
                       withData:@[reason]];
    }
}

#pragma mark - emitter

/// Send an event to the server, with optional data items.
-(void)emit:(NSString*)event items:(NSArray*)items
{
    if(_status == VPSocketIOClientStatusConnected) {
        NSMutableArray *array = [NSMutableArray arrayWithObject:event];
        [array addObjectsFromArray:items];
        [self emitData:array ack:-1];
    }
    else
    {
        [self handleClientEvent:eventStrings[@(VPSocketClientEventError)]
                       withData:@[@"Tried emitting \(event) when not connected"]];
    }
}

/// Sends a message to the server, requesting an ack.
-(VPSocketOnAckCallback*) emitWithAck:(NSString*)event items:(NSArray*)items
{
    NSMutableArray *array = [NSMutableArray arrayWithObject:event];
    [array addObjectsFromArray:items];
    return [self createOnAck:array];
}

-(void)emitData:(NSArray*)data ack:(int) ack
{
    if(_status == VPSocketIOClientStatusConnected) {
        VPSocketPacket *packet = [VPSocketPacket packetFromEmit:data id:ack nsp:_nsp ack:NO];
        NSString* str = packet.packetString;
        
        [DefaultSocketLogger.logger log:[NSString stringWithFormat:@"Emitting: %@", str] type:self.logType];
        [_engine send:str withData:packet.binary];
    }
    else {
        [self handleClientEvent:eventStrings[@(VPSocketClientEventError)]
                       withData:@[@"Tried emitting when not connected"]];
    }
}

// If the server wants to know that the client received data
-(void) emitAck:(int)ack withItems:(NSArray*)items
{
    if(_status == VPSocketIOClientStatusConnected) {
        
        VPSocketPacket *packet = [VPSocketPacket packetFromEmit:items id:ack nsp:_nsp ack:YES];
        NSString *str = packet.packetString;
        
        [DefaultSocketLogger.logger log:[NSString stringWithFormat:@"Emitting Ack: %@", str] type:self.logType];
        
        [_engine send:str withData:packet.binary];
    }
}

#pragma mark - namespace

/// Leaves nsp and goes back to the default namespace.
-(void) leaveNamespace {
    if(![_nsp isEqualToString: @"/"]) {
        [_engine send:@"1\(nsp)" withData: @[]];
        _nsp = @"/";
    }
}

/// Joins `namespace`.
-(void) joinNamespace:(NSString*) namespace
{
    _nsp = namespace;
    if(![_nsp isEqualToString: @"/"])
    {
        [DefaultSocketLogger.logger log:@"Joining namespace" type:self.logType];
        [_engine send:[NSString stringWithFormat:@"0\%@",_nsp] withData: @[]];
    }
}

#pragma mark - off

/// Removes handler(s) for a client event.
-(void) off:(NSString*) event
{
    [DefaultSocketLogger.logger log:[NSString stringWithFormat:@"Removing handler for event: %@", event] type:self.logType];
    NSPredicate *predicate= [NSPredicate predicateWithFormat:@"SELF.event != %@", event];
    [_handlers filterUsingPredicate:predicate];
}


/// Removes a handler with the specified UUID gotten from an `on` or `once`
-(void)offWithID:(NSUUID*)UUID {
    [DefaultSocketLogger.logger log:[NSString stringWithFormat:@"Removing handler with id: %@", UUID.UUIDString] type:self.logType];
    
    NSPredicate *predicate= [NSPredicate predicateWithFormat:@"SELF.uuid != %@", UUID];
    [_handlers filterUsingPredicate:predicate];
}

#pragma mark - on

/// Adds a handler for an event.
-(NSUUID*) on:(NSString*)event callback:(VPSocketOnEventCallback) callback
{
    [DefaultSocketLogger.logger log:[NSString stringWithFormat:@"Adding handler for event: %@", event] type:self.logType];
    VPSocketEventHandler *handler = [[VPSocketEventHandler alloc] initWithEvent:event
                                                                           uuid:[NSUUID UUID]
                                                                    andCallback:callback];
    [_handlers addObject:handler];
    return handler.uuid;
}

/// Adds a single-use handler for a client event.
-(NSUUID*) once:(NSString*)event callback:(VPSocketOnEventCallback) callback
{
    [DefaultSocketLogger.logger log:[NSString stringWithFormat:@"Adding once handler for event: %@", event] type:self.logType];
    
    NSUUID *uuid = [NSUUID UUID];
    
    __weak typeof(self) weakSelf = self;
    VPSocketEventHandler *handler = [[VPSocketEventHandler alloc] initWithEvent:event
                                                                           uuid:uuid
                                                                    andCallback:^(NSArray *data, VPSocketAckEmitter *emiter) {
        __strong typeof(self) strongSelf = weakSelf;
        if(strongSelf) {
            [strongSelf offWithID:uuid];
            callback(data, emiter);
        }
    }];
    [_handlers addObject:handler];
    return handler.uuid;
}

/// Adds a handler that will be called on every event.
-(void) onAny:(VPSocketAnyEventHandler)handler
{
    anyHandler = handler;
}

#pragma mark - reconnect

/// Tries to reconnect to the server.
-(void) reconnect {
    if(!reconnecting) {
        [_engine disconnect:@"manual reconnect"];
    }
}

/// Removes all handlers.
-(void) removeAllHandlers {
    [_handlers removeAllObjects];
}

-(void) tryReconnect:(NSString*)reason
{
    if(reconnecting)
    {
        [DefaultSocketLogger.logger log:@"Starting reconnect" type:self.logType];
        [self handleClientEvent:eventStrings[@(VPSocketClientEventReconnect)]
                       withData:@[reason]];
        [self _tryReconnect];
    }
}

-(void) _tryReconnect
{
    if( _reconnects && reconnecting && _status != VPSocketIOClientStatusDisconnected)
    {
        if(reconnectAttempts != -1 && currentReconnectAttempt + 1 > reconnectAttempts)
        {
            return [self didDisconnect: @"Reconnect Failed"];
        }
        else
        {
            [DefaultSocketLogger.logger log:@"Trying to reconnect" type:self.logType];
            [self handleClientEvent:eventStrings[@(VPSocketClientEventReconnectAttempt)]
                           withData:@[@(reconnectAttempts - currentReconnectAttempt)]];
            
            currentReconnectAttempt += 1;
            [self connect];
            
            [self setTimer];
        }
    }
}

-(void)setTimer
{
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_reconnectWait * NSEC_PER_SEC)), _handleQueue, ^
    {
       @autoreleasepool
       {
           __strong typeof(self) strongSelf = weakSelf;
           if(strongSelf != nil)
           {
               if(strongSelf.status != VPSocketIOClientStatusDisconnected &&
                  strongSelf.status != VPSocketIOClientStatusOpened)
               {
                   [strongSelf _tryReconnect];
               }
               else if(strongSelf.status != VPSocketIOClientStatusConnected)
               {
                   [strongSelf setTimer];
               }
           }
       }
    });
}

#pragma mark - VPSocketIOClientProtocol

/// Causes an event to be handled, and any event handlers for that event to be called.

-(void)handleEvent:(NSString*)event
          withData:(NSArray*) data
 isInternalMessage:(BOOL)internalMessage
{
    [self handleEvent:event withData:data
    isInternalMessage:internalMessage withAck:-1];
}

-(void)handleEvent:(NSString*)event
          withData:(NSArray*) data
 isInternalMessage:(BOOL)internalMessage
           withAck:(int)ack
{
    
    if(_status == VPSocketIOClientStatusConnected || internalMessage)
    {
        if([event isEqualToString:kSocketEventError])
        {
            [DefaultSocketLogger.logger error:data.firstObject type:self.logType];
        }
        else
        {
            [DefaultSocketLogger.logger log:[NSString stringWithFormat:@"Handling event: %@ with data: %@", event, data] type:self.logType];
        }
        
        if(anyHandler) {
            anyHandler([[VPSocketAnyEvent alloc] initWithEvent: event andItems: data]);
        }
        
        for (VPSocketEventHandler *hdl in [_handlers copy])
        {
            if([hdl.event isEqualToString: event])
            {
                [hdl executeCallbackWith:data withAck:ack withSocket:self];
            }
        }
    }
}

-(void) handleClientEvent:(NSString*)event withData:(NSArray*) data {
    [self handleEvent:event withData:data isInternalMessage:YES];
}

// Called when the socket gets an ack for something it sent
-(void) handleAck:(int)ack withData:(NSArray*)data {
    
    if(_status == VPSocketIOClientStatusConnected) {
        
        [DefaultSocketLogger.logger log:[NSString stringWithFormat:@"Handling ack: %d with data: %@", ack, data] type:self.logType];
        [ackHandlers executeAck:ack withItems:data onQueue: _handleQueue];
    }
}

-(void) didConnect:(NSString*) namespace
{
    [DefaultSocketLogger.logger log:@"Socket connected" type:self.logType];
    self.status = VPSocketIOClientStatusConnected;
    [self handleClientEvent:eventStrings[@(VPSocketClientEventConnect)]
                   withData:@[namespace]];
}

-(void)didError:(NSString*)reason {
    
    [self handleClientEvent:eventStrings[@(VPSocketClientEventError)] withData:@[reason]];
}

#pragma mark - VPSocketEngineClient

-(void) engineDidError:(NSString*)reason {
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(_handleQueue, ^
    {
        @autoreleasepool
        {
            __strong typeof(self) strongSelf = weakSelf;
            if(strongSelf) {
                [strongSelf _engineDidError:reason];
            }
        }
    });
}

-(void) _engineDidError:(NSString*)reason {
    [self handleClientEvent:eventStrings[@(VPSocketClientEventError)]
                   withData:@[reason]];
}

-(void) engineDidOpen:(NSString*)reason {
    self.status = VPSocketIOClientStatusOpened;
    [self handleClientEvent:eventStrings[@(VPSocketIOClientStatusOpened)]
                   withData:@[reason]];
}

-(void)engineDidClose:(NSString*)reason
{
    __weak typeof(self) weakSelf = self;
    dispatch_async(_handleQueue, ^
    {
        @autoreleasepool
        {
            __strong typeof(self) strongSelf = weakSelf;
            if(strongSelf) {
                [strongSelf _engineDidClose:reason];
            }
        }
    });
}

-(void) _engineDidClose:(NSString*)reason
{
    [_waitingPackets removeAllObjects];
    if (_status == VPSocketIOClientStatusDisconnected || !_reconnects)
    {
        [self didDisconnect:reason];
    }
    else
    {
        self.status = VPSocketIOClientStatusNotConnected;
        if (!reconnecting)
        {
            reconnecting = YES;
            [self tryReconnect:reason];
        }
    }
}

/// Called when the engine has a message that must be parsed.
-(void)parseEngineMessage:(NSString*)msg
{
    [DefaultSocketLogger.logger log:[NSString stringWithFormat:@"Should parse message: %@", msg] type:self.logType];
    __weak typeof(self) weakSelf = self;
    dispatch_async(_handleQueue, ^
    {
        @autoreleasepool
        {
            __strong typeof(self) strongSelf = weakSelf;
            if(strongSelf) {
                [strongSelf parseSocketMessage:msg];
            }
        }
    });
}

/// Called when the engine receives binary data.
-(void)parseEngineBinaryData:(NSData*)data
{
    __weak typeof(self) weakSelf = self;
    dispatch_async(_handleQueue, ^{
        @autoreleasepool
        {
            __strong typeof(self) strongSelf = weakSelf;
            if(strongSelf) {
                [strongSelf parseBinaryData:data];
            }
        }
    });
}

#pragma mark - VPSocketParsable

// Parses messages recieved
-(void)parseSocketMessage:(NSString*)message {
    
    if(message.length > 0)
    {
        [DefaultSocketLogger.logger log:[NSString stringWithFormat:@"Parsing %@", message] type:@"SocketParser"];
        
        VPSocketPacket *packet = [self parseString:message];
        
        if(packet) {
        
            [DefaultSocketLogger.logger log:[NSString stringWithFormat:@"Decoded packet as: %@", packet.description] type:@"SocketParser"];
            [self handlePacket:packet];
        }
        else {
            [DefaultSocketLogger.logger error:@"invalidPacketType" type: @"SocketParser"];
        }
    }
}

-(void)parseBinaryData:(NSData*)data
{
    if(_waitingPackets.count > 0)
    {
        VPSocketPacket *lastPacket = _waitingPackets.lastObject;
        BOOL success = [lastPacket addData:data];
        if(success) {
            [_waitingPackets removeLastObject];
            
            if(lastPacket.type != VPPacketTypeBinaryAck) {
                [self handleEvent:lastPacket.event
                         withData:lastPacket.args
                isInternalMessage:NO
                          withAck:lastPacket.id];
            }
            else {
                [self handleAck:lastPacket.id withData:lastPacket.args];
            }
        }
    }
    else {
        [DefaultSocketLogger.logger error:@"Got data when not remaking packet"
                                     type:@"SocketParser"];
    }
}


-(VPSocketPacket*)parseString:(NSString*)message
{
    NSCharacterSet* digits = [NSCharacterSet decimalDigitCharacterSet];
    VPStringReader *reader = [[VPStringReader alloc] init:message];
    
    NSString *packetType = [reader read:1];
    if ([packetType rangeOfCharacterFromSet:digits].location != NSNotFound) {
        VPPacketType type = [packetType integerValue];
        if(![reader hasNext]) {
            return [[VPSocketPacket alloc] init:type nsp:@"/" placeholders:0];
        }
        
        NSString *namespace = @"/";
        int placeholders = -1;
        
        if(type == VPPacketTypeBinaryAck || type == VPPacketTypeBinaryEvent) {
            NSString *value = [reader readUntilOccurence:@"-"];
            if ([value rangeOfCharacterFromSet:digits].location == NSNotFound) {
                return nil;
            }
            else {
                placeholders = [value intValue];
            }
        }
        
        NSString *charStr = [reader currentCharacter];
        if([charStr isEqualToString:namespace]) {
            namespace = [reader readUntilOccurence:@","];
        }
        
        if(![reader hasNext]) {
            return [[VPSocketPacket alloc] init:type nsp:namespace placeholders:placeholders];
        }
        
        NSMutableString *idString = [NSMutableString string];
        
        if(type == VPPacketTypeError) {
            [reader advance:-1];
        }
        else {
            while ([reader hasNext]) {
                NSString *value = [reader read:1];
                if ([value rangeOfCharacterFromSet:digits].location == NSNotFound) {
                    [reader advance:-2];
                    break;
                }
                else {
                    [idString appendString:value];
                }
            }
        }
        
        NSString *dataArray = [message substringFromIndex:reader.currentIndex+1];
        
        if (type == VPPacketTypeError && ![dataArray hasPrefix:@"["] && ![dataArray hasSuffix:@"]"])
        {
            dataArray =  [NSString stringWithFormat:@"[%@]", dataArray];
        }
        
        NSArray *data = [dataArray toArray];
        if(data.count > 0) {
            int idValue = -1;
            if(idString.length > 0)
            {
                idValue = [idString intValue];
            }
            return [[VPSocketPacket alloc] init:type
                                           data:data
                                             id:idValue
                                            nsp:namespace
                                   placeholders:placeholders
                                         binary:[NSArray array]];
        }
    }
    return nil;
}

#pragma mark - handle packet

-(BOOL) isCorrectNamespace:(NSString*) nsp
{
    return [nsp isEqualToString: self.nsp];
}

-(void)handlePacket:(VPSocketPacket*) packet
{
    switch (packet.type)
    {
        case VPPacketTypeEvent:
            if([self isCorrectNamespace:packet.nsp])
            {
                [self handleEvent:packet.event withData:packet.args isInternalMessage:NO
                          withAck:packet.id];
            }
            else
            {
                [DefaultSocketLogger.logger log:[NSString stringWithFormat:@"Got invalid packet: %@", packet.description]
                                           type:@"SocketParser"];
            }
            break;
        case VPPacketTypeAck:
            if([self isCorrectNamespace:packet.nsp])
            {
                [self handleAck:packet.id withData:packet.data];
            }
            else
            {
                [DefaultSocketLogger.logger log:[NSString stringWithFormat:@"Got invalid packet: %@", packet.description]
                                           type:@"SocketParser"];
            }
            break;
        case VPPacketTypeBinaryEvent:
        case VPPacketTypeBinaryAck:
            if([self isCorrectNamespace:packet.nsp]) {
                [_waitingPackets addObject:packet];
            }
            else {
                [DefaultSocketLogger.logger log:[NSString stringWithFormat:@"Got invalid packet: %@", packet.description]
                                           type:@"SocketParser"];
            }
            break;
        case VPPacketTypeConnect:
            [self handleConnect:packet.nsp];
            break;
        case VPPacketTypeDisconnect:
            [self didDisconnect:@"Got Disconnect"];
            break;
        case VPPacketTypeError:
            
            [self handleEvent:@"error" withData:packet.data isInternalMessage:YES
                      withAck:packet.id];
            break;
        default:
            [DefaultSocketLogger.logger log:[NSString stringWithFormat:@"Got invalid packet: %@", packet.description]
                                       type:@"SocketParser"];
            break;
    }
}

-(void)handleConnect:(NSString*)packetNamespace {
    if ([packetNamespace isEqualToString: @"/"] && ![_nsp isEqualToString:@"/"]) {
        [self joinNamespace:_nsp];
    } else {
        [self didConnect:packetNamespace];
    }
}

@end

