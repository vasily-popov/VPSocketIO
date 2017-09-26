Pod::Spec.new do |s|
  s.name         = "VPSocketIO"
  s.module_name  = "SocketIO"
  s.version      = "0.0.1"
  s.summary      = "Socket.IO client for iOS"
  s.description  = <<-DESC
                   Socket.IO-client for iOS.
                   Supports ws/wss/polling connections and binary.
                   For socket.io 2.0+ and Objective-C.
                   DESC
  s.license      = { :type => 'MIT' }
  s.author       = { "Vasily Popov" => "vasily.popov.it@gmail.com" }
  s.ios.deployment_target = '9.0'
  s.requires_arc = true
  s.source = {
    :git => "https://github.com/vascome/VPSocketIO.git",
    :tag => "#{s.version}"
  }
  s.source_files  = "Source/*.h", "Source/*.m"
end
