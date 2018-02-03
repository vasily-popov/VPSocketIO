Pod::Spec.new do |s|
  s.name         = "VPSocketIO"
  s.version      = "1.0.5"
  s.summary      = "Socket.IO client for iOS"
  s.description  = <<-DESC
                   Socket.IO-client for iOS.
                   Supports ws/wss/polling connections and binary.
                   For socket.io 2.0+ and Objective-C.
                   DESC
  s.homepage     = "https://github.com/vascome/VPSocketIO"
  s.license      = { :type => 'MIT' }
  s.author       = { "Vasily Popov" => "vasily.popov.it@gmail.com" }
  s.ios.deployment_target = '9.0'
  s.requires_arc = true
  s.source = {
    :git => "https://github.com/vascome/VPSocketIO.git",
    :tag => "#{s.version}",
    :submodules => true
  }
  s.source_files  = "Source/*.{h,m}", "jetfire/*.{h,m}"
end
