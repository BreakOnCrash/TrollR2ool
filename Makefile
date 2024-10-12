ARCHS = arm64 arm64e

TARGET := iphone:clang:16.5:14.0
INSTALL_TARGET_PROCESSES = TrollR2ool

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = TrollR2ool

TrollR2ool_FILES = main.m TRAppDelegate.m TRRootViewController.m TRRuntimeTool.m TRUtils.m
TrollR2ool_PRIVATE_FRAMEWORKS = SpringBoardServices
TrollR2ool_FRAMEWORKS = UIKit CoreGraphics MobileCoreServices
TrollR2ool_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/application.mk

after-stage::
	mkdir -p $(THEOS_STAGING_DIR)/Payload
	ldid -Sentitlements.plist $(THEOS_STAGING_DIR)/Applications/TrollR2ool.app/TrollR2ool
	cp -a $(THEOS_STAGING_DIR)/Applications/* $(THEOS_STAGING_DIR)/Payload
	mv $(THEOS_STAGING_DIR)/Payload .
	zip -q -r TrollR2ool.tipa Payload
	rm -rf Payload
	rm -rf packages/*