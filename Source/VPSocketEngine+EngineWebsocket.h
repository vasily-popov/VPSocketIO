//
//  VPSocketEngine+EngineWebsocket.h
//  VPSocketIO
//
//  Created by Vasily Popov on 9/26/17.
//  Copyright © 2017 Vasily Popov. All rights reserved.
//

#import "VPSocketEngine.h"
#import "VPSocketEngine+Private.h"

@interface VPSocketEngine (EngineWebsocket)

-(void) sendWebSocketMessage:(NSString*)message withType:(VPSocketEnginePacketType)type withData:(NSArray*)datas;
-(void) probeWebSocket;

@end
