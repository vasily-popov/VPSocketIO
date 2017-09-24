//
//  VPSocketPacket.m
//  VPSocketIO
//
//  Created by Vasily Popov on 9/19/17.
//  Copyright © 2017 Vasily Popov. All rights reserved.
//

#import "VPSocketPacket.h"
#import "DefaultSocketLogger.h"
@interface VPSocketPacket()
{
    int placeholders;
}

@property (nonatomic, strong, readonly) NSString* logType;

@end


@interface NSArray (JSON)

-(NSData*)toJSON:(NSError**)error;

@end

@implementation NSArray (JSON)

-(NSData*)toJSON:(NSError**)error
{
    return [NSJSONSerialization dataWithJSONObject:self options:0 error:error];
}

@end

@implementation VPSocketPacket

-(NSString *)description
{
    return [NSString stringWithFormat:@"SocketPacket {type:%lu; data: %@; id: %d; placeholders: %d; nsp: %@}", _type, _data, _id, placeholders, _nsp];
}

-(NSString *)logType {
    return @"VPSocketPacket";
}
        
-(NSArray *)args {
    if((_type == VPPacketTypeEvent || _type == VPPacketTypeBinaryEvent) && _data.count !=0 ) {
        return [_data subarrayWithRange:NSMakeRange(1, _data.count -1)];
    }
    else {
        return _data;
    }
}

-(NSString *)event {
    return [NSString stringWithFormat:@"%@", _data[0]];
}

-(NSString *)packetString {
    return [self createPacketString];
}

-(instancetype)init:(VPPacketType)type
               nsp:(NSString*)namespace
       placeholders:(int)_placeholders
{
    self = [super init];
    if(self) {
        _type = type;
        _nsp = namespace;
        placeholders = _placeholders;
    }
    return self;
}

-(instancetype)init:(VPPacketType)type data:(NSArray*)data
                 id:(int)id nsp:(NSString*)nsp placeholders:(int)_placeholders
             binary:(NSArray*)binary
{
    self = [super init];
    if(self) {
        _type = type;
        _data = [data mutableCopy];
        _id = id;
        _nsp = nsp;
        placeholders = _placeholders;
        _binary = [binary copy];
    }
    return self;
}

-(BOOL)addData:(NSData*)data {
    if(placeholders == _binary.count) {
        return YES;
    }
    [_binary addObject:data];
    
    if(placeholders == _binary.count) {
        [self fillInPlaceholders];
        return YES;
    }
    else {
        return NO;
    }
}


-(NSString*)completeMessage:(NSString*)message
{
    if(_data.count > 0) {
        NSError *error = nil;
        NSString *jsonString = nil;
        NSData *jsonSend = [_data toJSON:&error];
        if(jsonSend) {
            jsonString = [[NSString alloc] initWithData:jsonSend encoding:NSUTF8StringEncoding];
        }
        if(jsonSend && jsonString)
        {
            return [NSString stringWithFormat:@"%@%@", message, jsonString];
        }
        else
        {
            [DefaultSocketLogger.logger error:@"Error creating JSON object in SocketPacket.completeMessage" type:self.logType];
            return [NSString stringWithFormat:@"%@[]", message];
        }
        
    }
    else {
        return [NSString stringWithFormat:@"%@[]", message];
    }
    
}


-(NSString*) createPacketString
{
    NSString *typeString = [NSString stringWithFormat:@"%d", (int)_type];
    NSString *bString = @"";
    if(_type == VPPacketTypeBinaryEvent || _type == VPPacketTypeBinaryAck) {
        bString = [NSString stringWithFormat:@"%lu-", (unsigned long)_binary.count];
    }
    NSString *binaryCountString =  [typeString stringByAppendingString:bString];

    NSString *nsAddpString = [_nsp isEqualToString:@"/"]? @"": _nsp;
    NSString *nspString = [binaryCountString stringByAppendingString:nsAddpString];
    
    NSString *idString = [nspString stringByAppendingString:(self.id != -1 ? [NSString stringWithFormat:@"%d", self.id] : @"")];
    return [self completeMessage:idString];
}

-(void)fillInPlaceholders {
#warning TODO
    //_data = _data.map(_fillInPlaceholders)
}


-(id) _fillInPlaceholders:(id)object
{
    if([object isKindOfClass:[NSDictionary class]])
    {
        NSDictionary *dict = object;
        NSNumber *value = dict[@"_placeholder"];
        if(value.boolValue) {
            NSNumber *num = dict[@"num"];
            return _binary[num.intValue];
        }
        else {
#warning TODO
           /* return dict.reduce(JSON(), {cur, keyValue in
                var cur = cur
                
                cur[keyValue.0] = _fillInPlaceholders(keyValue.1)
                
                return cur
            })
            */
            return object;
        }
    }
    else if ([object isKindOfClass:[NSArray class]]) {
#warning TODO
        //return arr.map(_fillInPlaceholders)
        return object;
    }
    else {
        return object;
    }
}


+(VPSocketPacket*)packetFromEmit:(NSArray*)items id:(int)id nsp:(NSString*)nsp ack:(BOOL)ack {
    
    NSMutableArray *binary = [NSMutableArray array];
    NSArray *parsedData =  nil;
    
    VPPacketType type = [self findType:binary.count ack: ack];
    return [[VPSocketPacket alloc] init:type data:parsedData id:id nsp:nsp placeholders:0 binary:binary];
    
}


+(VPPacketType) findType:(NSInteger)binCount ack:(BOOL)ack
{
    if(binCount == 0)
    {
        return ack?VPPacketTypeAck:VPPacketTypeEvent;
    }
    else if(binCount > 0)
    {
        return ack?VPPacketTypeBinaryAck:VPPacketTypeBinaryEvent;
    }
    return VPPacketTypeError;
}

@end
