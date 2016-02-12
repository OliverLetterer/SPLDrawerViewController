#
# Be sure to run `pod lib lint NAME.podspec' to ensure this is a
# valid spec and remove all comments before submitting the spec.
#
# Any lines starting with a # are optional, but encouraged
#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "SPLDrawerViewController"
  s.version          = "0.5.0"
  s.summary          = "iOS 7 / 8 drawer view controller."
  s.description      = "Like notification center, just from the right screen edge."
  s.homepage         = "https://github.com/OliverLetterer/SPLDrawerViewController"
  s.license          = 'MIT'
  s.author           = { "Oliver Letterer" => "oliver.letterer@gmail.com" }
  s.source           = { :git => "https://github.com/OliverLetterer/SPLDrawerViewController.git", :tag => s.version.to_s }

  s.platform     = :ios, '8.0'
  s.requires_arc = true

  s.source_files = 'Pod/Classes'
  s.weak_frameworks = 'UIKit'
end
