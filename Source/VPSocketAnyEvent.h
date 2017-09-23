//
//  VPSocketAnyEvent.h
//  VPSocketIO
//
//  Created by Vasily Popov on 9/19/17.
//  Copyright © 2017 Vasily Popov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VPSocketIOUtils.h"
#import "VPSocketIOClientProtocol.h"

@class VPSocketIOClient;

@interface VPSocketAnyEvent : NSObject

@property (nonatomic, strong, readonly) NSString* event;
@property (nonatomic, strong, readonly) NSArray *items;

-(instancetype)initWithEvent:(NSString*)event andItems:(NSArray*)items;

@end


@interface VPSocketEventHandler : NSObject

@property (nonatomic, strong, readonly) NSString* event;
@property (nonatomic, strong, readonly) NSUUID *uuid;
@property (nonatomic, strong, readonly) VPSocketNormalCallback callback;

-(instancetype)initWithEvent:(NSString*)event uuid:(NSUUID*)uuid andCallback:(VPSocketNormalCallback)callback;

-(void)executeCallbackWith:(NSArray*)items withAck:(int)ack withSocket:(VPSocketIOClient*)socket;
@end
