# VPSocketIO
Socket.IO client for iOS. Supports socket.io 2.0+

It's based on a official Swift library from here: [SocketIO-Client-Swift](https://github.com/socketio/socket.io-client-swift)

It uses Jetfire [Jetfire](https://github.com/acmacalister/jetfire)

## Objective-C Example
```objective-c
#import <SocketIO-iOS/SocketIO-iOS.h>;
NSURL* url = [[NSURL alloc] initWithString:@"http://localhost:8080"];
SocketIOClient* socket = [[SocketIOClient alloc] initWithSocketURL:url config:@{@"log": @YES];

[socket on:@"connect" callback:^(NSArray* data, SocketAckEmitter* ack) {
    NSLog(@"socket connected");
}];

[socket connect];

```

## Features
- Supports socket.io 2.0+
- Supports binary
- Supports Polling and WebSockets
- Supports TLS/SSL

## Installation

### Carthage
Add these line to your `Cartfile`:
```
github "vascome/vpsocketio" ~> 1.0.3 # Or latest version
```

Run `carthage update --platform ios,macosx`.

### CocoaPods 1.0.0 or later
Create `Podfile` and add `pod 'vpsocketio'`:

```ruby

target 'MyApp' do
    pod 'vpsocketio', '~> 1.0.3' # Or latest version
end
```

## License
MIT

