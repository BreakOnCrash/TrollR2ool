build:
	xcrun clang -fobjc-arc -framework UIKit -isysroot /Users/whoami/theos/sdks/iPhoneOS16.5.sdk -arch arm64 -miphoneos-version-min=11.0 main.m -o Payload/TestApp1.app/TestApp1
	ldid -Sentitlements.plist Payload/TestApp1.app/TestApp1
	zip -q -r TestApp1.tipa Payload