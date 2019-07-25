Pod::Spec.new do |s|
  s.name             = 'DYJSBridge'
  s.version          = '1.0'
  s.summary          = 'An easy way to implement js and OC Call'
  s.homepage         = 'https://github.com/dongyang-source/DYJSBridge'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'dongyang' => '1060380608@qq.com' }
  s.source           = { :git => 'https://github.com/dongyang-source/DYJSBridge.git', :tag => s.version.to_s }
  s.source_files = 'DYJSBridge/*.{h,m}'
  s.resource = 'DYJSBridge/*.js'
  s.private_header_files = 'DYJSBridge/InjectionObjectInfo.h'
  s.frameworks = 'UIKit'
  s.platform     = :ios,'8.0'
  s.requires_arc = true
end
