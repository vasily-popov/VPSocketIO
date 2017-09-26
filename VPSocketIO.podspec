Pod::Spec.new do |s|
  s.name         = "VPSocketIO"
  s.module_name  = "SocketIO"
  s.version      = "1.0.0"
  s.summary      = "Socket.IO-client for iOS and OS X"
  s.description  = <<-DESC
                   Socket.IO-client for iOS and OS X.
                   Supports ws/wss/polling connections and binary.
                   For socket.io 2.0+ and Objective-C.
                   DESC
  s.license      = { :type => 'MIT' }
  s.author       = { "Vasily Popov" => "vasily.popov.it@gmail.com" }
  s.ios.deployment_target = '9.0'
  s.osx.deployment_target = '10.10'
  s.tvos.deployment_target = '9.0'
  s.requires_arc = true
  s.source = {
    :git => "https://github.com/vascome/VPSocketIO.git",
    :tag => "#{s.version}"
  }
  s.source_files  = "Source/*.h", "Source/*.m"
#  s.dependency "jetfire", git => "https://github.com/acmacalister/jetfire.git", tag => "0.1.6"
end
