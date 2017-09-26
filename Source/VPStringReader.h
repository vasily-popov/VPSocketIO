//
//  VPStringReader.h
//  VPSocketIO
//
//  Created by Vasily Popov on 9/23/17.
//  Copyright © 2017 Vasily Popov. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface VPStringReader : NSObject

@property (nonatomic, strong, readonly) NSString *message;
@property (nonatomic) int currentIndex;

-(instancetype)init:(NSString*)message;

-(NSString*)currentCharacter;

-(BOOL)hasNext;

-(NSString*)read:(int)count;
-(NSString*)readUntilOccurence:(NSString*)string;
-(NSString*)readUntilEnd;

-(int)advance:(int)offset;

@end
