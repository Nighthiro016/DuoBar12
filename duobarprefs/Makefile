TARGET := iphone:clang:latest:12.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = DuoBarPrefs

DuoBarPrefs_FILES = DuoRootListController.m
DuoBarPrefs_FRAMEWORKS = UIKit
DuoBarPrefs_LDFLAGS = -undefined dynamic_lookup
DuoBarPrefs_INSTALL_PATH = /Library/PreferenceBundles
DuoBarPrefs_CFLAGS = -fobjc-arc -Wno-deprecated-declarations

include $(THEOS_MAKE_PATH)/bundle.mk
