TARGET := iphone:clang:latest:15.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = KeychainClearCrul
KeychainClearCrul_FILES = Tweak.xm
KeychainClearCrul_CFLAGS = -fobjc-arc
KeychainClearCrul_FRAMEWORKS = Foundation Security
KeychainClearCrul_FILTER = com.atebits.Tweetie2

PACKAGE_NAME = com.example.keychainclearcrul
PACKAGE_VERSION = 1.0.0
PACKAGE_ARCH = iphoneos-arm
PACKAGE_DESCRIPTION = Rootless Keychain control tweak with Unix socket interface
PACKAGE_MAINTAINER = DP
PACKAGE_SECTION = Tweaks
PACKAGE_DEPENDS = firmware (>= 15.0)

include $(THEOS_MAKE_PATH)/tweak.mk
