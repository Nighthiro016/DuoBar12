#import "DuoRootListController.h"
#import <spawn.h>

#define DUO_DOMAIN_C CFSTR("local.duobar.ios12")
#define DUO_NOTIFY_C CFSTR("local.duobar.ios12/prefs")

@implementation DuoRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (void)resetSize {
    CFPreferencesSetAppValue(CFSTR("SizeScale"), (__bridge CFPropertyListRef)@100, DUO_DOMAIN_C);
    CFPreferencesAppSynchronize(DUO_DOMAIN_C);
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), DUO_NOTIFY_C, NULL, NULL, YES);
    [self reloadSpecifiers];
}

- (void)respring {
    pid_t pid;
    const char *args[] = {"killall", "-9", "SpringBoard", NULL};
    posix_spawn(&pid, "/usr/bin/killall", NULL, NULL, (char *const *)args, NULL);
}

@end
