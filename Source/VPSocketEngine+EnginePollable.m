//
//  VPSocketEngine+EnginePollable.m
//  VPSocketIO
//
//  Created by Vasily Popov on 9/26/17.
//  Copyright © 2017 Vasily Popov. All rights reserved.
//

#import "VPSocketEngine+EnginePollable.h"
#import "VPSocketEngine+Private.h"
#import "DefaultSocketLogger.h"
#import "VPStringReader.h"
#import "NSString+VPSocketIO.h"

typedef void (^EngineURLSessionDataTaskCallBack)(NSData* data, NSURLResponse*response, NSError*error);

@implementation VPSocketEngine (EnginePollable)

- (void)doLongPoll:(NSURLRequest *)request {
    self.waitingForPoll = YES;
    
    __weak typeof(self) weakSelf = self;
    
    [self doRequest:request withCallback:^(NSData *data, NSURLResponse *response, NSError *error)
     {
         __strong typeof(self) strongSelf = weakSelf;
         if(strongSelf)
         {
             if(strongSelf.polling)
             {
                 NSInteger status = 200;
                 if([response isKindOfClass:[NSHTTPURLResponse class]]) {
                     status = ((NSHTTPURLResponse*)response).statusCode;
                     if(status/100 != 2 && error == nil) {
                         NSString *errorString = [NSHTTPURLResponse localizedStringForStatusCode:status];
                         if(errorString.length > 0)
                         {
                             error = [NSError errorWithDomain:@"VPSocketEngine"
                                                         code:status
                                                     userInfo:@{NSLocalizedDescriptionKey:errorString}];
                         }
                     }
                 }
                 
                 if(error != nil || data == nil || (status/100 != 2))
                 {
                     NSString *errorString = error.localizedDescription.length > 0?error.localizedDescription:@"Error";
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
    
    if( !self.websocket && !self.waitingForPoll && self.connected && !self.closed)
    {
        NSMutableURLRequest*request =  [[NSMutableURLRequest alloc] initWithURL:[self urlPollingWithSid]];
        [self addHeaders:request];
        [self doLongPoll:request];
    }
}

// We need to take special care when we're polling that we send it ASAP
// Also make sure we're on the engineQueue since we're touching postWait
-(void) disconnectPolling
{
    [self.postWait addObject: [NSString stringWithFormat:@"%lu", (unsigned long)VPSocketEnginePacketTypeClose]];
    [self doRequest:[self createRequestForPostWithPostWait] withCallback:nil];
}

- (void)parsePollingMessage:(NSString *)string {
    
    if(string.length > 0) {
        
        [DefaultSocketLogger.logger log:[NSString stringWithFormat:@"Got poll message:%@", string] type:@"SocketEnginePolling"];
        
        NSCharacterSet* digits = [NSCharacterSet decimalDigitCharacterSet];
        VPStringReader *reader = [[VPStringReader alloc] init:string];
        
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
    
    [DefaultSocketLogger.logger log:[NSString stringWithFormat:@"Sending poll: %@ as type:%@", message, self.stringEnginePacketType[@(type)]] type:@"SocketEnginePolling"];
    
    [self.postWait addObject:[NSString stringWithFormat:@"%lu%@", (unsigned long)type,message]];
    
    if(!self.websocket) {
        for (NSData *data in array) {
            NSString *stringToSend = [self createBinaryStringDataForSend:data];
            if(stringToSend) {
                [self.postWait addObject:stringToSend];
            }
        }
    }
    if(!self.waitingForPost) {
        [self flushWaitingForPost];
    }
}

- (void)stopPolling {
    self.waitingForPoll = NO;
    self.waitingForPost = NO;
    [self.session finishTasksAndInvalidate];
}

- (NSURL *)urlPollingWithSid
{
    NSURLComponents *components = [NSURLComponents componentsWithURL:self.urlPolling resolvingAgainstBaseURL:NO];
    NSString *sidComponent = [NSString stringWithFormat:@"&sid=%@", self.sid!= nil?[self.sid urlEncode]:@""];
    components.percentEncodedQuery = [NSString stringWithFormat:@"%@%@", components.percentEncodedQuery,sidComponent];
    return components.URL;
}
- (void)flushWaitingForPost
{
    if(self.postWait.count > 0 && self.connected)
    {
        if(self.websocket)
        {
            [self flushWaitingForPostToWebSocket];
        }
        else
        {
            NSURLRequest *request =  [self createRequestForPostWithPostWait];
            self.waitingForPost = YES;
            
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

- (void)doRequest:(NSURLRequest *)request withCallback:(EngineURLSessionDataTaskCallBack)callback
{
    if(self.polling && !self.closed && !self.invalidated && !self.fastUpgrade) {
        
        [DefaultSocketLogger.logger log:[NSString stringWithFormat:@"Doing polling %@ %@", request.HTTPMethod?:@"", request.URL.absoluteString] type:@"SocketEnginePolling"];
        [[self.session dataTaskWithRequest:request completionHandler:callback] resume];
    }
}

- (NSURLRequest *)createRequestForPostWithPostWait
{
    NSMutableString* postStr = [NSMutableString string];;
    for (NSString *packet in self.postWait) {
        [postStr appendFormat:@"%ld:%@",(unsigned long)packet.length, packet];
    }
    
    [self.postWait removeAllObjects];
    
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

-(NSString*)createBinaryStringDataForSend:(NSData *)data  {
    return [NSString stringWithFormat:@"b4%@", [data base64EncodedStringWithOptions:0]];
}

@end
