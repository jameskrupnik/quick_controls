Pod::Spec.new do |s|
  s.name             = 'quick_controls'
  s.version          = '0.1.0'
  s.summary          = 'iOS 18 Control widgets and Android Quick Settings tiles from one Dart API.'
  s.description      = <<-DESC
Declare a control from Dart and it appears in Control Center, on the Lock
Screen and under the Action button. Taps are recorded as pending events in an
App Group, which the app drains on resume.
                       DESC
  s.homepage         = 'https://github.com/jameskrupnik/quick_controls'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Illumination Development' => 'james.krupnik@illuminationdevelopment.com' }
  s.source           = { :path => '.' }

  # The plugin plus the one kit file it shares with the widget extension.
  # QuickControlWidgets.swift and QuickControlIntents.swift are deliberately
  # not listed: they belong in the host's extension target, not in Runner.
  # See Package.swift for the same split under Swift Package Manager.
  s.source_files = [
    'quick_controls/Sources/quick_controls/**/*.swift',
    'quick_controls/Sources/QuickControlsKit/QuickControlsStore.swift',
  ]
  s.dependency 'Flutter'
  # 15, not 13: see Package.swift.
  s.platform = :ios, '15.0'
  s.frameworks = 'WidgetKit'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
  s.resource_bundles = {'quick_controls_privacy' => ['quick_controls/Sources/quick_controls/PrivacyInfo.xcprivacy']}
end
