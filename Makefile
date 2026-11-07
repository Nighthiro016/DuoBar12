# DuoBar for iPhone 5s (arm64) on iOS 12, rootful (unc0ver / checkra1n / Odyssey-era layout).
TARGET := iphone:clang:latest:12.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DuoBar12
DuoBar12_FILES = Tweak.xm DuoGlyphView.m
DuoBar12_CFLAGS = -fobjc-arc -Wall -Wno-deprecated-declarations
DuoBar12_FRAMEWORKS = UIKit CoreGraphics QuartzCore SystemConfiguration

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += duobarprefs
include $(THEOS_MAKE_PATH)/aggregate.mk
