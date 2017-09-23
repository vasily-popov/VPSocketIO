//
//  VPSocketIOUtils.h
//  VPSocketIO
//
//  Created by Vasily Popov on 9/19/17.
//  Copyright © 2017 Vasily Popov. All rights reserved.
//

#ifndef VPSocketIOUtils_H
#define VPSocketIOUtils_H

#import <Foundation/Foundation.h>
#import "VPSocketEngineProtocol.h"

@class VPSocketAckEmitter;
@class VPSocketAnyEvent;

typedef void (^VPSocketHandler)(void);
typedef void (^VPAckCallback)(NSArray*array);
typedef void (^VPSocketNormalCallback)(NSArray*array, VPSocketAckEmitter*emitter);
typedef void (^VPSocketAnyEventHandler)(VPSocketAnyEvent*event);


#endif
