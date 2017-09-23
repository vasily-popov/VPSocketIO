//
//  VPSocketStremReader.m
//  VPSocketIO
//
//  Created by Vasily Popov on 9/23/17.
//  Copyright © 2017 Vasily Popov. All rights reserved.
//

#import "VPSocketStreamReader.h"

@interface VPSocketStreamReader()

@end

@implementation VPSocketStreamReader

-(instancetype)init:(NSString*)message {
    self = [super init];
    if(self) {
        self.message = message;
        _currentIndex = 0;
    }
    return self;
}

-(BOOL)hasNext {
    return _currentIndex != _message.length -1;
}

-(NSString*)currentCharacter {
    unichar character =  [_message characterAtIndex:_currentIndex];
    
    return [[NSString alloc] initWithBytes:&character length:sizeof(unichar) encoding:NSUTF8StringEncoding];
    
}

-(int)advance:(int)offset
{
    _currentIndex += offset;
    return _currentIndex;
}

-(NSString*)read:(int)count {
#warning TODO
    //let readString = String(message.utf16[currentIndex..<message.utf16.index(currentIndex, offsetBy: count)])!
    //advance(by: count)
    return [NSString string];
}

-(NSString*)readUntilOccurence:(NSString*)string {
#warning TODO
    //let substring = message.utf16[currentIndex..<message.utf16.endIndex]
    
    //guard let foundIndex = substring.index(of: string.utf16.first!) else {
    //    currentIndex = message.utf16.endIndex
    //
    //    return String(substring)!
    // }
    //advance(by: substring.distance(from: substring.startIndex, to: foundIndex) + 1)
    
    //return String(substring[substring.startIndex..<foundIndex])!
    
    return [NSString string];
}

-(NSString*)readUntilEnd
{
#warning TODO
    //return read(count: message.utf16.distance(from: currentIndex, to: message.utf16.endIndex))
    return [NSString string];
}

@end

