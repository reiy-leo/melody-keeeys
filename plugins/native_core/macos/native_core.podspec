#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint native_core.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'native_core'
  s.version          = '0.0.1'
  s.summary          = 'Native audio engine and key hooks for Melody Keeeys.'
  s.description      = <<-DESC
miniaudio-based FFI audio engine (audio_engine.c) compiled into the Runner
binary, plus the CGEventTap global key hook plugin (Swift).
                       DESC
  s.homepage         = 'https://github.com/melody-keeeys/melody-keeeys'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Melody Keeeys' => 'dev@melodykeeeys.dev' }

  s.source           = { :path => '.' }
  # Shared C sources live under Classes/src so the pod picks them up with the
  # Swift plugin (Windows/Linux CMake reference the same files).
  # Swift plugin + C engine in one static pod: ae_* symbols end up in the
  # Runner binary (DynamicLibrary.process()).
  s.source_files = 'Classes/**/*'

  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.15'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17' }
  s.swift_version = '5.0'
end
