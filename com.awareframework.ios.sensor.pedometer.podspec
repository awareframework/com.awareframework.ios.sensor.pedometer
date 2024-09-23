#
# Be sure to run `pod lib lint com.awareframework.ios.sensor.pedometer.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'com.awareframework.ios.sensor.pedometer'
  s.version          = '0.7.1'
  s.summary          = 'A Pedometer Module for AWARE Framework'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
The Pedometer sensor allows us to manages historic pedometer data which is provided by [CMPedometer](https://developer.apple.com/documentation/coremotion). The pedometer object contains step counts and other information about the distance traveled and the number of floors ascended or descended.
                       DESC

  s.homepage         = 'https://github.com/awareframework/com.awareframework.ios.sensor.pedometer'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'Apache2', :file => 'LICENSE' }
  s.author           = { 'Yuuki Nishiyama' => 'nishiyama@csis.u-tokyo.ac.jp' }
  s.source           = { :git => 'https://github.com/awareframework/com.awareframework.ios.sensor.pedometer.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.platform              = :ios, '12.0'
  s.ios.deployment_target = '12.0'
  
  s.swift_version = '5'

  s.source_files = 'com.awareframework.ios.sensor.pedometer/Classes/**/*'

  s.frameworks = 'CoreMotion'
  s.dependency 'com.awareframework.ios.sensor.core', '~>0.7'
  
end
