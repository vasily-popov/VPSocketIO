//
//  SocketAckManager.h
//  VPSocketIO
//
//  Created by Vasily Popov on 9/20/17.
//  Copyright © 2017 Vasily Popov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VPSocketIOUtils.h"

@interface VPSocketAckManager : NSObject

-(void)addAck:(int)ack callback:(VPAckCallback)callback;
-(void)executeAck:(int)ack withItems:(NSArray*)items onQueue:(dispatch_queue_t)queue;
-(void)timeoutAck:(int)ack onQueue:(dispatch_queue_t)queue;


@end


@interface VPSocketAck : NSObject

@property (nonatomic) int ack;
@property (nonatomic, strong) VPAckCallback callback;

-(instancetype)initWithAck:(int)ack andCallBack:(VPAckCallback)callback;

@end

