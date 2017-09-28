//
//  VPSocketEngineProtocol.h
//  VPSocketIO
//
//  Created by Vasily Popov on 9/19/17.
//  Copyright © 2017 Vasily Popov. All rights reserved.
//

#ifndef VPSocketEngineProtocol_H
#define VPSocketEngineProtocol_H

#import <Foundation/Foundation.h>

@protocol VPSocketEngineClient <NSObject>

@required

/// Called when the engine errors.
-(void)engineDidError:(NSString*)reason;
/// Called when the engine opens.
-(void)engineDidOpen:(NSString*)reason;
/// Called when the engine closes.
-(void)engineDidClose:(NSString*)reason;
/// Called when the engine has a message that must be parsed.
-(void)parseEngineMessage:(NSString*)msg;
/// Called when the engine receives binary data.
-(void)parseEngineBinaryData:(NSData*)data;

@end


@protocol VPSocketEngineProtocol <NSObject>

@required

@property (nonatomic, weak) id<VPSocketEngineClient> client;
@property (nonatomic, readonly) BOOL closed;
@property (nonatomic, readonly) BOOL connected;

/// Starts the connection to the server.
-(void)connect;
/// Disconnects from the server.
-(void)disconnect:(NSString*)reason;
// reset client
-(void)syncResetClient;

-(void)send:(NSString*)msg withData:(NSArray<NSData*>*) data;

@end

#endif

