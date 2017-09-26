//
//  VPSocketAck.h
//  VPSocketIO
//
//  Created by Vasily Popov on 9/26/17.
//  Copyright © 2017 Vasily Popov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VPSocketIOClientProtocol.h"

@interface VPSocketAck : NSObject

@property (nonatomic, readonly) int ack;
@property (nonatomic, strong, readonly) VPScoketAckArrayCallback callback;

-(instancetype)initWithAck:(int)ack andCallBack:(VPScoketAckArrayCallback)callback;

@end

