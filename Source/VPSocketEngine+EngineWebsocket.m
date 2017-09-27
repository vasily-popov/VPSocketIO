//
//  VPSocketEngine+EngineWebsocket.m
//  VPSocketIO
//
//  Created by Vasily Popov on 9/26/17.
//  Copyright © 2017 Vasily Popov. All rights reserved.
//

#import "VPSocketEngine+EngineWebsocket.h"
#import "DefaultSocketLogger.h"

@implementation VPSocketEngine (EngineWebsocket)


-(void) sendWebSocketMessage:(NSString*)message withType:(VPSocketEnginePacketType)type withData:(NSArray*)datas
{
    [DefaultSocketLogger.logger log:[NSString stringWithFormat:@"Sending ws: %@ as type:%@", message, self.stringEnginePacketType[@(type)]] type:@"SocketEngineWebSocket"];
    
    [self.ws writeString:[NSString stringWithFormat:@"%lu%@",(unsigned long)type, message]];
    if(self.websocket)
    {
        for (NSData *data in datas)
        {
            NSData *binData = [self createBinaryDataForSend:data];
            [self.ws writeData:binData];
        }
    }
}
-(void) probeWebSocket
{
    if([self.ws isConnected])
    {
        [self sendWebSocketMessage:@"probe" withType:VPSocketEnginePacketTypePing withData:@[]];
    }
}

- (NSData*)createBinaryDataForSend:(NSData *)data
{
    const Byte byte = 0x4;
    NSMutableData *byteData = [NSMutableData dataWithBytes:&byte length:sizeof(Byte)];
    [byteData appendData:data];
    return  byteData;
}

@end
