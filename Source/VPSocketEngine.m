//
//  SocketEngine.m
//  VPSocketIO
//
//  Created by Vasily Popov on 9/19/17.
//  Copyright © 2017 Vasily Popov. All rights reserved.
//

#import "VPSocketEngine.h"
#import "NSString+VPSocketIO.h"
#import "VPSocketStreamReader.h"
#import "DefaultSocketLogger.h"
#import <Jetfire/Jetfire.h>

@interface VPProbe : NSObject

@property (nonatomic, strong) NSString *message;
@property (nonatomic) VPSocketEnginePacketType type;
@property (nonatomic, strong) NSArray *data;

@end

@implementation VPProbe

@end

@interface VPSocketEngine()<VPSocketEnginePollableProtocol,
                            JFRWebSocketDelegate,
                            NSURLSessionDelegate>

@property (nonatomic, strong, readonly) NSString* logType;

@property (nonatomic) BOOL closed;
@property (nonatomic) BOOL compress;
@property (nonatomic) BOOL connected;
@property (nonatomic, strong) NSMutableArray<NSHTTPCookie*>* cookies;
@property (nonatomic, strong) NSMutableDictionary*extraHeaders;
@property (nonatomic) BOOL fastUpgrade;

@property (nonatomic) BOOL polling;
@property (nonatomic) BOOL forcePolling;
@property (nonatomic) BOOL forceWebsockets;
@property (nonatomic) BOOL probing;

@property (nonatomic, strong) NSString *sid;
@property (nonatomic, strong) NSString *socketPath;
@property (nonatomic, strong) NSURL *urlPolling;
@property (nonatomic, strong) NSURL *urlWebSocket;

@property (nonatomic) BOOL websocket;
@property (nonatomic, strong) JFRWebSocket* ws;

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

@property (nonatomic, strong) NSMutableArray<NSString*>* postWait;


@end


@implementation VPSocketEngine

@synthesize waitingForPoll, waitingForPost, invalidated, session, client;


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
    waitingForPoll = NO;
    waitingForPost = NO;
    invalidated = NO;
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


#pragma mark - private methods

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

-(void) handleBase64:(NSString*)message {
    
    // binary in base64 string
    NSString *noPrefix;
#warning TODO
    //let noPrefix = message[message.index(message.startIndex, offsetBy: 2)..<message.endIndex]
    
    NSData *data = [[NSData alloc] initWithBase64EncodedString:noPrefix options:NSDataBase64DecodingIgnoreUnknownCharacters];
    
    if(data != nil) {
        [client parseEngineBinaryData:data];
    }
}

-(void) closeOutEngine:(NSString*)reason
{
    _sid = @"";
    _closed = YES;
    invalidated = YES;
    _connected = NO;
    
    [_ws disconnect];
    [self stopPolling];
    [client engineDidClose:reason];
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
        
        for (NSString *key in _connectParams.allKeys) {
            NSString *value = _connectParams[key];
            NSString *encodedKey = [key urlEncode];
            NSString *encodedValue = [value urlEncode];
            [queryString appendFormat:@"&%@=%@", encodedKey, encodedValue];
        }
        
        urlWebSocketComponent.percentEncodedQuery = [NSString stringWithFormat:@"transport=websocket%@",queryString];
        urlPollingComponent.percentEncodedQuery = [NSString stringWithFormat:@"transport=polling%@&b64=1",queryString];
        _urlPolling = urlPollingComponent.URL;
        _urlWebSocket = urlWebSocketComponent.URL;
        
    }
}


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


#pragma mark - VPSocketEngineWebsocketProtocol

-(void) sendWebSocketMessage:(NSString*)message withType:(VPSocketEnginePacketType)type withData:(NSArray*)datas
{
    [DefaultSocketLogger.logger log:[NSString stringWithFormat:@"Sending ws: %@ as type:%lu", message, type] type:@"SocketEngineWebSocket"];
    
    [_ws writeString:[NSString stringWithFormat:@"%lu%@",type, message]];
    if(_websocket) {
        for (NSData *data in datas) {
            NSData *binData = [self createBinaryDataForSend:data];
            [_ws writeData:binData];
        }
    }
}
-(void) probeWebSocket
{
    if([_ws isConnected]) {
        [self sendWebSocketMessage:@"probe" withType:VPSocketEnginePacketTypePing withData:@[]];
    }
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
        [client engineDidClose:@"Disconnect"];
    }
    else
    {
        if(_websocket) {
            [self flushProbeWait];
        }
        else
        {
            _connected = NO;
            _websocket = NO;
            
            NSString *reason = error.localizedDescription;
            if(reason.length > 0)
            {
                [self didError:reason];
            }
            else
            {
                [client engineDidClose:@"Socket Disconnected"];
            }
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

#pragma mark - VPSocketEngineProtocol

#pragma mark - connect
- (void)connect {
    
    dispatch_async(_engineQueue, ^{
        [self _connect];
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

-(void)didError:(NSString*)reason
{
    [DefaultSocketLogger.logger error:reason type:self.logType];
    [client engineDidError:reason];
    [self disconnect:reason];
}

#pragma mark - disconnect

-(void) disconnect:(NSString*)reason
{
    dispatch_async(_engineQueue, ^{
        [self _disconnect:reason];
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

// We need to take special care when we're polling that we send it ASAP
// Also make sure we're on the engineQueue since we're touching postWait
-(void) disconnectPolling
{
    [_postWait addObject: [NSString stringWithFormat:@"%lu", VPSocketEnginePacketTypeClose]];
    [self doRequest:[self createRequestForPostWithPostWait] withCallback:nil];
}

- (NSURLRequest *)createRequestForPostWithPostWait
{
    NSMutableString* postStr = [NSMutableString string];;
    for (NSString *packet in _postWait) {
        [postStr appendFormat:@"%ld:%@",packet.length, packet];
    }
    
    [_postWait removeAllObjects];
    
    [DefaultSocketLogger.logger log:[NSString stringWithFormat:@"Created POST string:%@", postStr] type:@"SocketEnginePolling"];
    
    
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[self urlPollingWithSid]];
    NSData *postData =[postStr dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
    
    [self addHeaders:req];
    
    req.HTTPMethod = @"POST";
    [req setValue:@"text/plain; charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
    req.HTTPBody = postData;
    [req setValue:[NSString stringWithFormat:@"%lu", (unsigned long)postData.length] forHTTPHeaderField:@"Content-Length"];
    return req;
}

-(void) doFastUpgrade
{
    if (waitingForPoll) {
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

-(void) handleClose:(NSString*)reason
{
    [client engineDidClose:reason];
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
    
    VPSocketStreamReader *reader = [[VPSocketStreamReader alloc] init:message];
    
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

-(void)resetEngine {
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    queue.underlyingQueue = _engineQueue;
    _closed = NO;
    _connected = NO;
    _fastUpgrade = NO;
    _polling = YES;
    _probing = NO;
    invalidated = NO;
    session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:_sessionDelegate delegateQueue:queue];
    _sid = @"";
    waitingForPoll = NO;
    waitingForPost = NO;
    _websocket = NO;
}

-(void) sendPing
{
    if(_connected && _pingInterval > 0) {
        if(_pongsMissed > _pongsMissedMax) {
            [client engineDidClose:@"Ping timeout"];
        }
        else {
            _pongsMissed += 1;
            [self write:@"" withType:VPSocketEnginePacketTypePing withData:@[]];
            
            __weak typeof(self) weakSelf = self;
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_pingInterval/1000 * NSEC_PER_SEC)),_engineQueue, ^{
                __strong typeof(self) strongSelf = weakSelf;
                if(strongSelf) {
                    [strongSelf sendPing];
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
    });
}



- (void)doLongPoll:(NSURLRequest *)request {
    waitingForPoll = YES;
    
    __weak typeof(self) weakSelf = self;
    
    [self doRequest:request withCallback:^(NSData *data, NSURLResponse *response, NSError *error)
    {
        __strong typeof(self) strongSelf = weakSelf;
        if(strongSelf)
        {
            if(strongSelf.polling)
            {
                if(error != nil || data == nil)
                {
                    NSString *errorString = error.localizedDescription.length > 0?error.localizedDescription:@"Error";
                    [DefaultSocketLogger.logger error:errorString type:@"SocketEnginePolling"];
                    [strongSelf didError:errorString];
                }
                else
                {
                    [DefaultSocketLogger.logger log:@"Got polling response" type:@"SocketEnginePolling"];
                    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    if(str)
                    {
                        [strongSelf parsePollingMessage:str];
                    }
                    strongSelf.waitingForPoll = NO;
                    if(strongSelf.fastUpgrade)
                    {
                        [strongSelf doFastUpgrade];
                    }
                    else if (!strongSelf.closed && strongSelf.polling)
                    {
                        [strongSelf doPoll];
                    }
                }
            }
        }
    }];
}

- (void)doPoll {
    
    if( !_websocket && !waitingForPoll && _connected && !_closed)
    {
        NSMutableURLRequest*request =  [[NSMutableURLRequest alloc] initWithURL:[self urlPollingWithSid]];
        [self addHeaders:request];
        [self doLongPoll:request];
    }
}

- (void)doRequest:(NSURLRequest *)request withCallback:(VPEngineResponseCallBack)callback {
    
    if(_polling && !_closed && !invalidated && !_fastUpgrade) {
        
        [DefaultSocketLogger.logger log:[NSString stringWithFormat:@"Doing polling %@ %@", request.HTTPMethod?:@"", request.URL.absoluteString] type:@"SocketEnginePolling"];
        [[session dataTaskWithRequest:request completionHandler:callback] resume];
    }
}

- (void)flushWaitingForPost
{
    if(_postWait.count > 0 && _connected)
    {
        if(_websocket)
        {
            [self flushWaitingForPostToWebSocket];
        }
        else
        {
            NSURLRequest *request =  [self createRequestForPostWithPostWait];
            waitingForPost = YES;
            
            [DefaultSocketLogger.logger log:@"POSTing" type:@"SocketEnginePolling"];
            
            __weak typeof(self) weakSelf = self;
            [self doRequest:request withCallback:^(NSData *data, NSURLResponse *response, NSError *error)
            {
                __strong typeof(self) strongSelf = weakSelf;
                if(strongSelf)
                {
                    if(error != nil)
                    {
                        NSString *errorString = error.localizedDescription.length > 0?error.localizedDescription:@"Error";
                        [DefaultSocketLogger.logger error:errorString type:@"SocketEnginePolling"];
                        if (strongSelf.polling)
                        {
                            [strongSelf didError:errorString];
                        }
                    }
                    else
                    {
                        strongSelf.waitingForPost = NO;
                        if(!strongSelf.fastUpgrade)
                        {
                            [strongSelf flushWaitingForPost];
                            [strongSelf doPoll];
                        }
                    }
                }
            }];
        }
    }
}

- (void)parsePollingMessage:(NSString *)string {
    
    if(string.length > 0) {
        
        [DefaultSocketLogger.logger log:[NSString stringWithFormat:@"Got poll message:%@", string] type:@"SocketEnginePolling"];
        
        NSCharacterSet* digits = [NSCharacterSet decimalDigitCharacterSet];
        VPSocketStreamReader *reader = [[VPSocketStreamReader alloc] init:string];
        
        while ([reader hasNext]) {
            
            NSString *count = [reader readUntilOccurence:@":"];
            if ([count rangeOfCharacterFromSet:digits].location != NSNotFound) {
                [self parseEngineMessage:[reader read:(int)count.integerValue]];
            }
            else {
                [self parseEngineMessage:string];
                break;
            }
        }
    }
}

- (void)sendPollMessage:(NSString *)message withType:(VPSocketEnginePacketType)type withData:(NSArray *)array {
    
    [DefaultSocketLogger.logger log:[NSString stringWithFormat:@"Sending poll: %@ as type:%lu", message, type] type:@"SocketEnginePolling"];
    
    [_postWait addObject:[NSString stringWithFormat:@"%lu%@", type,message]];
    
    if(!_websocket) {
        for (NSData *data in array) {
            NSString *stringToSend = [self createBinaryStringDataForSend:data];
            if(stringToSend) {
                [_postWait addObject:stringToSend];
            }
        }
    }
    if(!waitingForPost) {
        [self flushWaitingForPost];
    }
}

- (void)stopPolling {
    waitingForPoll = NO;
    waitingForPost = NO;
    [session finishTasksAndInvalidate];
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

-(NSString*)createBinaryStringDataForSend:(NSData *)data  {
    return [NSString stringWithFormat:@"b4%@", [data base64EncodedStringWithOptions:0]];
}

- (NSData*)createBinaryDataForSend:(NSData *)data {
    
    const Byte byte = 0x4;
    NSMutableData *byteData = [NSMutableData dataWithBytes:&byte length:sizeof(Byte)];
    [byteData appendData:data];
    return  byteData;
}

- (void)send:(NSString *)msg withData:(NSArray<NSData *> *)data {
    [self write:msg withType:VPSocketEnginePacketTypeMessage withData:data];
}

- (NSURL *)urlPollingWithSid {
    NSURLComponents *components = [NSURLComponents componentsWithURL:_urlPolling resolvingAgainstBaseURL:NO];
    NSString *sidComponent = [NSString stringWithFormat:@"&sid=%@", _sid!= nil?[_sid urlEncode]:@""];
    components.percentEncodedQuery = [NSString stringWithFormat:@"%@%@", components.percentEncodedQuery,sidComponent];
    return components.URL;
}

#pragma mark - NSURLSessionDelegate

- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(nullable NSError *)error
{
    [DefaultSocketLogger.logger error:@"Engine URLSession became invalid" type:self.logType];
    [self didError:@"Engine URLSession became invalid"];
}

@end
