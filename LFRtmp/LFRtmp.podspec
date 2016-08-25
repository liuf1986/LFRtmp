Pod::Spec.new do |s|
  s.name             = "LFRtmp"
  s.version          = "1.0.0"
  s.summary          = "A RTMP SDK  used on iOS."
  s.description      = <<-DESC
                       It is a rtmp sdk used on iOS, which implement by Objective-C.
                       DESC
  s.homepage         = "https://github.com/liuf1986"
  s.license          = { :type => "MIT", :file => "../LICENSE" }
  s.author           = { "liufang" => "zglf1986@126.com" }
  s.source           = { :git => "https://liuf1986@github.com/liuf1986/LFRtmp.git", :tag => s.version.to_s }
  s.platform     = :ios, '7.0'
  s.ios.deployment_target = "7.0"
  s.source_files = 'LFRtmp/LFRtmp/**/*.{h,m,mm,cpp,c}'
  s.public_header_files = ["LFRtmp/LFRtmp/**/*.h","LFRtmp/LFRtmp/*.h"]
  s.frameworks = 'AVFoundation', 'CoreAudio', 'AudioToolbox','VideoToolbox','CoreMedia','CoreVideo','OpenGLES','QuartzCore'
  s.libraries = "c++", "z"
  s.requires_arc = true
  
  s.subspec 'no-arc' do |sp|
    sp.source_files = 'LFRtmp/LFRtmp/amf/**/*.{h,m}'
    sp.requires_arc = false
  end


end