//
//  SocketEngine.m
//  VPSocketIO
//
//  Created by Vasily Popov on 9/19/17.
//  Copyright © 2017 Vasily Popov. All rights reserved.
//

#import "VPSocketEngine.h"
#import "NSString+VPSocketIO.h"
#import "VPStringReader.h"
#import "DefaultSocketLogger.h"
#import "VPSocketEngine+Private.h"
#import "VPSocketEngine+EnginePollable.h"
#import "VPSocketEngine+EngineWebsocket.h"

@interface VPProbe : NSObject

@property (nonatomic, strong) NSString *message;
@property (nonatomic) VPSocketEnginePacketType type;
@property (nonatomic, strong) NSArray *data;

@end

@implementation VPProbe

@end

@interface VPSocketEngine()<JFRWebSocketDelegate,
                            NSURLSessionDelegate>
@property (nonatomic, strong, readonly) NSString* logType;

@property (nonatomic) BOOL closed;
@property (nonatomic) BOOL compress;
@property (nonatomic) BOOL connected;
@property (nonatomic, strong) NSMutableArray<NSHTTPCookie*>* cookies;
@property (nonatomic, strong) NSMutableDictionary *connectParams;
@property (nonatomic, strong) NSMutableDictionary*extraHeaders;
@property (nonatomic, strong) dispatch_queue_t engineQueue;

@property (nonatomic, strong) NSString *socketPath;
@property (nonatomic, strong) NSURL *urlWebSocket;

@property (nonatomic, weak) id<NSURLSessionDelegate> sessionDelegate;
@property (nonatomic, strong) NSURL *url;

@property (nonatomic) int pingInterval;
@property (nonatomic) int pingTimeout;

@property (nonatomic) int pongsMissed;
@property (nonatomic) int pongsMissedMax;
@property (nonatomic) BOOL secure;
@property (nonatomic) BOOL selfSigned;

@property (nonatomic, strong) JFRSecurity* security;
@property (nonatomic, strong) NSMutableArray<VPProbe*>* probeWait;


@end


@implementation VPSocketEngine

@synthesize client;

-(instancetype)initWithClient:(id<VPSocketEngineClient>)client url:(NSURL*)url options:(NSDictionary*)config
{
    self = [super init];
    if(self){
        [self setup];
        self.client = client;
        self.url = url;
        
        for (NSString*key in config.allKeys)
        {
            id value = [config valueForKey:key];
            if([key isEqualToString:@"connectParams"])
            {
                _connectParams = value;
            }
            if([key isEqualToString:@"cookies"])
            {
                _cookies = value;
            }
            
            if([key isEqualToString:@"extraHeaders"])
            {
                _extraHeaders = value;
            }
            
            if([key isEqualToString:@"sessionDelegate"])
            {
                _sessionDelegate = value;
            }
            
            if([key isEqualToString:@"forcePolling"])
            {
                _forcePolling = [value boolValue];
            }
            
            if([key isEqualToString:@"forceWebsockets"])
            {
                _forceWebsockets = [value boolValue];
            }
            
            if([key isEqualToString:@"path"])
            {
                _socketPath = value;
                
                if (![_socketPath hasSuffix:@"/"]) {
                    _socketPath = [_socketPath stringByAppendingString:@"/"];
                }
            }
            
            if([key isEqualToString:@"secure"])
            {
                _secure = [value boolValue];
            }
            
            if([key isEqualToString:@"selfSigned"])
            {
                _selfSigned = [value boolValue];
            }
            
            if([key isEqualToString:@"security"])
            {
                _security = value;
            }
            
            if([key isEqualToString:@"compress"])
            {
                _compress = YES;
            }
        }
        
        if(_sessionDelegate == nil)
        {
            _sessionDelegate = self;
        }
        [self createURLs];
        
    }
    return self;
}


-(void)setup {
    _engineQueue = dispatch_queue_create("com.socketio.engineHandleQueue", NULL);
    _postWait = [[NSMutableArray alloc] init];
    _waitingForPoll = NO;
    _waitingForPost = NO;
    _invalidated = NO;
    _closed = NO;
    _compress = NO;
    _connected = NO;
    _fastUpgrade = NO;
    _polling = YES;
    _forcePolling = NO;
    _forceWebsockets = NO;
    _probing = NO;
    _sid = @"";
    _socketPath = @"/engine.io/";
    _urlPolling = [NSURL URLWithString:@"http://localhost/"];
    _urlWebSocket = [NSURL URLWithString:@"http://localhost/"];
    _websocket = NO;
    _pingTimeout = 0;
    _pongsMissed = 0;
    _pongsMissedMax = 0;
    _probeWait = [NSMutableArray array];
    _secure = NO;
    _selfSigned = NO;
    
    _stringEnginePacketType = @{ @(VPSocketEnginePacketTypeOpen) : @"open",
                                 @(VPSocketEnginePacketTypeClose) : @"close",
                                 @(VPSocketEnginePacketTypePing) : @"ping",
                                 @(VPSocketEnginePacketTypePong) : @"pong",
                                 @(VPSocketEnginePacketTypeMessage) : @"message",
                                 @(VPSocketEnginePacketTypeUpgrade) : @"upgrade",
                                 @(VPSocketEnginePacketTypeNoop) : @"noop"
                               };
}

-(void)dealloc {
    
    [DefaultSocketLogger.logger log:@"Engine is being released" type:self.logType];
    _closed = YES;
    [self stopPolling];
}

#pragma mark - property

-(NSString*)logType {
    return @"SocketEngine";
}

-(void)setConnectParams:(NSMutableDictionary *)connectParams {
    _connectParams = connectParams;
    [self createURLs];
}

-(void)setPingTimeout:(int)pingTimeout {
    _pingTimeout = pingTimeout;
    _pongsMissedMax = (int)(_pingTimeout/(_pingInterval> 0 ? _pingTimeout: 25000));
}

-(void) createURLs
{
    if (client == nil) {
        _urlPolling = [NSURL URLWithString:@"http://localhost/"];
        _urlWebSocket = [NSURL URLWithString:@"http://localhost/"];
    }
    else {
        NSURLComponents *urlPollingComponent = [NSURLComponents componentsWithString:_url.absoluteString];
        NSURLComponents *urlWebSocketComponent = [NSURLComponents componentsWithString:_url.absoluteString];
        NSMutableString *queryString = [NSMutableString string];
        
        urlWebSocketComponent.path = _socketPath;
        urlPollingComponent.path = _socketPath;
        
        if(_secure) {
            urlWebSocketComponent.scheme = @"wss";
            urlPollingComponent.scheme = @"https";
        }
        else {
            urlWebSocketComponent.scheme = @"ws";
            urlPollingComponent.scheme = @"http";
        }
        
        for (id key in _connectParams.allKeys) {
            NSString *encodedKey = [key urlEncode];
            id value = _connectParams[key];
            if([value isKindOfClass:[NSString class]]) {
                NSString *encodedValue = [(NSString*)value urlEncode];
                [queryString appendFormat:@"&%@=%@", encodedKey, encodedValue];
            }
            else if([value isKindOfClass:[NSArray class]]){
                NSArray *array = value;
                for (id item in array) {
                    if([item isKindOfClass:[NSString class]]) {
                        NSString *encodedValue = [item urlEncode];
                        [queryString appendFormat:@"&%@=%@", encodedKey, encodedValue];
                    }
                }
            }
        }
        
        urlWebSocketComponent.percentEncodedQuery = [NSString stringWithFormat:@"transport=websocket%@",queryString];
        urlPollingComponent.percentEncodedQuery = [NSString stringWithFormat:@"transport=polling%@&b64=1",queryString];
        _urlPolling = urlPollingComponent.URL;
        _urlWebSocket = urlWebSocketComponent.URL;
        
    }
}

#pragma mark - create websocket

-(void) createWebSocketAndConnect
{
    _ws = [[JFRWebSocket alloc] initWithURL:self.urlWebSocketWithSid protocols:nil];
    
    if(_cookies != nil) {
        NSDictionary *headers = [NSHTTPCookie requestHeaderFieldsWithCookies:_cookies];
        
        for (id key in headers.allKeys) {
            [_ws addHeader:headers[key] forKey:key];
        }
        
    }
    
    for (id key in _extraHeaders.allKeys) {
        [_ws addHeader:_extraHeaders[key] forKey:key];
    }
    
    _ws.queue = _engineQueue;
    //_ws.enableCompression = _compress;
    _ws.delegate = self;
    _ws.selfSignedSSL = _selfSigned;
    _ws.security = _security;
    [_ws connect];
}

#pragma mark - VPSocketEngineProtocol

-(void)syncResetClient
{
    if(_engineQueue != NULL) {
        dispatch_sync(_engineQueue, ^{
            self.client = nil;
        });
    }
}

#pragma mark - connect
- (void)connect {
    
    dispatch_async(_engineQueue, ^
    {
        @autoreleasepool
        {
            [self _connect];
        }
    });
}

-(void) _connect
{
    if (_connected)
    {
        [DefaultSocketLogger.logger error:@"Engine tried opening while connected. Assuming this was a reconnect" type:self.logType];
        [self disconnect:@"reconnect"];
    }
    
    [DefaultSocketLogger.logger log:[NSString stringWithFormat:@"Starting engine. Server: %@", _url.absoluteString] type:self.logType];
    [DefaultSocketLogger.logger log:@"Handshaking" type:self.logType];
    
    [self resetEngine];
    
    if (_forceWebsockets)
    {
        _polling = NO;
        _websocket = YES;
        [self createWebSocketAndConnect];
    }
    else
    {
        NSMutableURLRequest *reqPolling = [NSMutableURLRequest requestWithURL:_urlPolling
                                                                  cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                              timeoutInterval:60.0];
        
        [self addHeaders:reqPolling];
        [self doLongPoll:reqPolling];
    }
}

- (NSURL *)urlWebSocketWithSid {
    
    NSURLComponents *components = [NSURLComponents componentsWithURL:_urlWebSocket resolvingAgainstBaseURL:NO];
    NSString *sidComponent = _sid.length > 0? [NSString stringWithFormat:@"&sid=%@", [_sid urlEncode]] : @"";
    components.percentEncodedQuery = [NSString stringWithFormat:@"%@%@", components.percentEncodedQuery,sidComponent];
    return components.URL;
}

-(void)resetEngine {
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    queue.underlyingQueue = _engineQueue;
    _closed = NO;
    _connected = NO;
    _fastUpgrade = NO;
    _polling = YES;
    _probing = NO;
    _invalidated = NO;
    _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:_sessionDelegate delegateQueue:queue];
    _sid = @"";
    _waitingForPoll = NO;
    _waitingForPost = NO;
    _websocket = NO;
}

#pragma mark - disconnect

-(void) disconnect:(NSString*)reason
{
    dispatch_async(_engineQueue, ^
    {
        @autoreleasepool
        {
            [self _disconnect:reason];
        }
    });
}

-(void)_disconnect:(NSString*)reason
{
    if(_connected) {
        [DefaultSocketLogger.logger log:@"Engine is being closed." type:self.logType];
        if(!_closed) {
            if (_websocket) {
                [self sendWebSocketMessage:@"" withType:VPSocketEnginePacketTypeClose withData:@[]];
            }
            else {
                [self disconnectPolling];
            }
        }
    }
    [self closeOutEngine:reason];
}

#pragma mark - private methods

-(void)didError:(NSString*)reason
{
    if(!self.closed) {
        [client engineDidError:reason];
        [self disconnect:reason];
    }
}

-(void) checkAndHandleEngineError:(NSString*) message
{
    NSDictionary *dict = [message toDictionary];
    if (dict != nil) {
        NSString *error = dict[@"message"];
        if(error != nil) {
            [self didError: error];
        }
    }
    else {
        [client engineDidError:[NSString stringWithFormat:@"Got unknown error from server %@", message]];
    }
}

-(void) handleBase64:(NSString*)message
{
    // binary in base64 string
    NSString *noPrefix = [message substringFromIndex:2]; //remove prefix b4
    NSData *data = [[NSData alloc] initWithBase64EncodedString:noPrefix options:NSDataBase64DecodingIgnoreUnknownCharacters];
    
    if(data != nil) {
        [client parseEngineBinaryData:data];
    }
}

-(void) closeOutEngine:(NSString*)reason
{
    _sid = @"";
    _closed = YES;
    _invalidated = YES;
    _connected = NO;
    
    [_ws disconnect];
    [self stopPolling];
    [client engineDidClose:reason];
}


-(void) doFastUpgrade
{
    if (_waitingForPoll) {
        [DefaultSocketLogger.logger error:@"Outstanding poll when switched to WebSockets, we'll probably disconnect soon. You should report this." type:self.logType];
    }
    
    [self sendWebSocketMessage:@"" withType:VPSocketEnginePacketTypeUpgrade withData: @[]];
    _websocket = YES;
    _polling = NO;
    _fastUpgrade = NO;
    _probing = NO;
    [self flushProbeWait];
}

-(void)flushProbeWait
{
    [DefaultSocketLogger.logger log:@"Flushing probe wait" type:self.logType];
    for (VPProbe *waiter in _probeWait) {
        [self write:waiter.message withType:waiter.type withData:waiter.data];
    }
    [_probeWait removeAllObjects];
    if(_postWait.count > 0) {
        [self flushWaitingForPostToWebSocket];
    }
}

-(void) flushWaitingForPostToWebSocket
{
    if(_ws != nil) {
        for (NSString *packet in _postWait) {
            [_ws writeString:packet];
        }
    }
    
    [_postWait removeAllObjects];
}

#pragma mark - parse engine

/// Parses raw binary received from engine.io.
-(void) parseEngineData:(NSData*)data
{
    [DefaultSocketLogger.logger log:[NSString stringWithFormat:@"Got binary data:%@",data] type:self.logType];
    [client parseEngineBinaryData:[data subdataWithRange:NSMakeRange(1, data.length-1)]];
}

/// Parses a raw engine.io packet.
-(void)parseEngineMessage:(NSString*)message
{
    [DefaultSocketLogger.logger log:[NSString stringWithFormat:@"Got message:%@",message] type:self.logType];
    
    if(message.length > 0)
    {
        VPStringReader *reader = [[VPStringReader alloc] init:message];
        
        if([message hasPrefix:@"b4"]) {
            [self handleBase64:message];
        }
        else {
            NSCharacterSet* digits = [NSCharacterSet decimalDigitCharacterSet];
            NSString *currentType = [reader currentCharacter];
            if ([currentType rangeOfCharacterFromSet:digits].location != NSNotFound) {
                VPSocketEnginePacketType type = [currentType intValue];
                switch (type) {
                    case VPSocketEnginePacketTypeOpen:
                        [self handleOpen:[message substringFromIndex:1]];
                        break;
                    case VPSocketEnginePacketTypeClose:
                        [self handleClose:message];
                        break;
                    case VPSocketEnginePacketTypePong:
                        [self handlePong:message];
                        break;
                    case VPSocketEnginePacketTypeNoop:
                        [self handleNOOP];
                        break;
                    case VPSocketEnginePacketTypeMessage:
                        [self handleMessage:[message substringFromIndex:1]];
                        break;
                    default:
                        [DefaultSocketLogger.logger log:@"Got unknown packet type" type:self.logType];
                        break;
                }
            }
            else {
                [self checkAndHandleEngineError:message];
            }
        }
    }
}

#pragma mark - handle messages

-(void) handleClose:(NSString*)reason
{
    [self closeOutEngine:reason];
}

-(void) handleMessage:(NSString*)message
{
    [client parseEngineMessage:message];
}

-(void) handleNOOP
{
    [self doPoll];
}


-(void) handleOpen:(NSString*)openData
{
    NSDictionary *json = [openData toDictionary];
    if(json != nil) {
        NSString *sid = json[@"sid"];
        if([sid isKindOfClass:[NSString class]]) {
            BOOL upgradeWs = NO;
            self.sid = sid;
            _connected = YES;
            _pongsMissed = 0;
            
            NSArray<NSString*> *upgrades = json[@"upgrades"];
            if(upgrades != nil) {
                upgradeWs = [upgrades containsObject:@"websocket"];
            }
            
            NSNumber *interval = json[@"pingInterval"];
            NSNumber *timeout = json[@"pingTimeout"];
            if([interval isKindOfClass:[NSNumber class]] && interval.intValue > 0 &&
               [timeout isKindOfClass:[NSNumber class]] && timeout.intValue > 0) {
                self.pingInterval = interval.intValue;
                self.pingTimeout = timeout.intValue;
            }
            
            if( !_forcePolling && !_forceWebsockets && upgradeWs) {
                [self createWebSocketAndConnect];
            }
            
            [self sendPing];
            
            if(!_forceWebsockets) {
                [self doPoll];
            }
            
            [client engineDidOpen:@"Connect"];
        }
        else {
            [self didError:@"Open packet contained no sid"];
        }
    }
    else {
        [self didError:@"Error parsing open packet"];
    }
}


-(void)handlePong:(NSString*)message
{
    _pongsMissed = 0;
    // We should upgrade
    if ([message isEqualToString:@"3probe"]) {
        [self upgradeTransport];
    }
}

-(void) sendPing
{
    if(_connected && _pingInterval > 0) {
        if(_pongsMissed > _pongsMissedMax) {
            [self closeOutEngine:@"Ping timeout"];
        }
        else {
            _pongsMissed += 1;
            [self write:@"" withType:VPSocketEnginePacketTypePing withData:@[]];
            
            __weak typeof(self) weakSelf = self;
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_pingInterval/1000 * NSEC_PER_SEC)),_engineQueue, ^
            {
                @autoreleasepool
                {
                    __strong typeof(self) strongSelf = weakSelf;
                    if(strongSelf) {
                        [strongSelf sendPing];
                    }
                }
            });
        }
    }
}

-(void) upgradeTransport {
    if( [_ws isConnected]) {
        
        [DefaultSocketLogger.logger log:@"Upgrading transport to WebSockets" type:self.logType];
        _fastUpgrade = YES;
        [self sendPollMessage:@"" withType:VPSocketEnginePacketTypeNoop withData:@[]];
    }
}

/// Writes a message to engine.io, independent of transport.
-(void) write:(NSString*)msg withType:(VPSocketEnginePacketType)type withData:(NSArray*)data
{
    dispatch_async(_engineQueue, ^
    {
        @autoreleasepool
        {
            if(self.connected)
            {
                if(self.websocket)
                {
                    [DefaultSocketLogger.logger log:[NSString stringWithFormat:@"Writing ws: %@ has data: %@", msg, data.count>0?@"true":@"false"] type:self.logType];
                    [self sendWebSocketMessage:msg withType:type withData:data];
                }
                else if (!self.probing)
                {
                    [DefaultSocketLogger.logger log:[NSString stringWithFormat:@"Writing poll:%@ has data: %@", msg, data.count>0?@"true":@"false"] type:self.logType];
                    [self sendPollMessage:msg withType:type withData:data];
                }
                else
                {
                    VPProbe *probe = [[VPProbe alloc] init];
                    probe.message = msg;
                    probe.type = type;
                    probe.data = data;
                    [self.probeWait addObject:probe];
                }
            }
        }
    });
}

- (void)addHeaders:(NSMutableURLRequest *)request {
    
    if(_cookies.count > 0) {
        request.allHTTPHeaderFields = [NSHTTPCookie requestHeaderFieldsWithCookies:_cookies];
    }
    
    if (_extraHeaders) {
        for (NSString *key in _extraHeaders.allKeys) {
            [request setValue:_extraHeaders[key] forHTTPHeaderField:key];
        }
    }
}

- (void)send:(NSString *)msg withData:(NSArray<NSData *> *)data {
    [self write:msg withType:VPSocketEnginePacketTypeMessage withData:data];
}

#pragma mark - NSURLSessionDelegate

- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(nullable NSError *)error
{
    [self didError:@"Engine URLSession became invalid"];
}

#pragma mark - JFRWebSocketDelegate

-(void)websocketDidConnect:(JFRWebSocket*)socket
{
    if(!_forceWebsockets)
    {
        _probing = YES;
        [self probeWebSocket];
    }
    else
    {
        _connected = YES;
        _probing = NO;
        _polling = NO;
    }
}
-(void)websocketDidDisconnect:(JFRWebSocket*)socket error:(NSError*)error
{
    _probing = NO;
    
    if(_closed)
    {
        [self closeOutEngine:@"Disconnect"];
    }
    else
    {
        if(_websocket)
        {
            [self flushProbeWait];
        }
        else
        {
            _connected = NO;
            _websocket = NO;
            
            NSString *reason = @"Socket Disconnected";
            if(error.localizedDescription.length > 0)
            {
                reason = error.localizedDescription;
            }
            [self closeOutEngine:reason];
        }
    }
}

-(void)websocket:(JFRWebSocket*)socket didReceiveMessage:(NSString*)string
{
    [self parseEngineMessage:string];
}
-(void)websocket:(JFRWebSocket*)socket didReceiveData:(NSData*)data
{
    [self parseEngineData:data];
}

@end
