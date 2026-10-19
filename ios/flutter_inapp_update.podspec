#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_inapp_update.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_inapp_update'
  s.version          = '0.0.1'
  s.summary          = 'Flutter plugin for in-app updates on Android (Play Core) and iOS (App Store version check).'
  s.description      = <<-DESC
Flutter plugin for in-app updates on Android (Play Core) and iOS (App Store version check).
                       DESC
  s.homepage         = 'https://github.com/nameisjayant/flutter_flutter_inapp_update'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'nameisjayant' => 'nameisjayant@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'flutter_inapp_update/Sources/flutter_inapp_update/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'flutter_inapp_update_privacy' => ['flutter_inapp_update/Sources/flutter_inapp_update/PrivacyInfo.xcprivacy']}
end
