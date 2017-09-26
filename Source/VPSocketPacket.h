//
//  VPSocketPacket.h
//  VPSocketIO
//
//  Created by Vasily Popov on 9/19/17.
//  Copyright © 2017 Vasily Popov. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum : NSUInteger {
    VPPacketTypeConnect = 0,
    VPPacketTypeDisconnect,
    VPPacketTypeEvent,
    VPPacketTypeAck,
    VPPacketTypeError,
    VPPacketTypeBinaryEvent,
    VPPacketTypeBinaryAck
    
} VPPacketType;

@interface VPSocketPacket : NSObject

@property (nonatomic, strong, readonly) NSString *packetString;
@property (nonatomic, strong, readonly) NSMutableArray<NSData*> *binary;
@property (nonatomic, readonly) VPPacketType type;
@property (nonatomic, readonly) int id;
@property (nonatomic, strong, readonly) NSString *event;
@property (nonatomic, strong, readonly) NSArray *args;
@property (nonatomic, strong, readonly) NSString *nsp;
@property (nonatomic, strong, readonly) NSMutableArray *data;

-(instancetype)init:(VPPacketType)type
                nsp:(NSString*)namespace
       placeholders:(int)plholders;
-(instancetype)init:(VPPacketType)type
               data:(NSArray*)data
                 id:(int)id
                nsp:(NSString*)nsp
       placeholders:(int)plholders
             binary:(NSArray*)binary;

+(VPSocketPacket*)packetFromEmit:(NSArray*)items id:(int)id nsp:(NSString*)nsp ack:(BOOL)ack;

-(BOOL)addData:(NSData*)data;

@end
