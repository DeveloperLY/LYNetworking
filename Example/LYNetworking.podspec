#
# Be sure to run `pod lib lint LYNetworking.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'LYNetworking'
  s.version          = '1.0.0'
  s.summary          = '对AFNetworking网络请求的二次封装，支持RESTful API'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
对iOS网络请求第三方库AFNetworking的二次封装，隔离对第三方库的直接使用，支持RESTful API。
                       DESC

  s.homepage         = 'https://github.com/DeveloperLY/LYNetworking'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'DeveloperLY' => 'coderyliu@gmail.com' }
  s.source           = { :git => 'https://github.com/DeveloperLY/LYNetworking.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '8.0'

  s.source_files = 'LYNetworking/Classes/**/*'
  
  # s.resource_bundles = {
  #   'LYNetworking' => ['LYNetworking/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  s.dependency 'AFNetworking', 'YYCache'
end
