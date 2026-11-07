// DuoBar for iPhone 5s / iOS 12.
//
// iOS 12 on a non-notch iPhone still uses the LEGACY status bar (UIStatusBar + UIStatusBarItemView
// subclasses). Newer DuoBar builds hook the modern _UIStatusBar classes, which do not exist here, so
// this is a separate implementation with the same look:
//   - the battery item view hosts one custom glyph (ring + Wi-Fi + 4 cellular dots + percentage)
//   - the signal, Wi-Fi/data and battery-percentage item views collapse to zero width
//   - the signal and Wi-Fi item views are still read for their bar counts
#import <UIKit/UIKit.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <string.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "DuoGlyphView.h"

@interface UIStatusBarItemView : UIView
- (CGFloat)updateContentsAndWidth;
- (BOOL)updateForNewData:(id)data actions:(int)actions;
@end

@interface UIStatusBarBatteryItemView : UIStatusBarItemView
@end

@interface UIStatusBarBatteryItemView (DuoBar12)
@property (nonatomic, strong) DuoGlyphView *duoGlyph;
@end

@interface UIStatusBarBatteryPercentItemView : UIStatusBarItemView
@end

@interface UIStatusBarSignalStrengthItemView : UIStatusBarItemView
@end

@interface UIStatusBarDataNetworkItemView : UIStatusBarItemView
@end

#pragma mark - Helpers

static BOOL gIsSpringBoard = NO;

// SpringBoard is unsandboxed, so it can write a small log you can open in Filza:
// /var/mobile/duobar12.log
static void DuoLog(NSString *fmt, ...) NS_FORMAT_FUNCTION(1, 2);
static void DuoLog(NSString *fmt, ...) {
    if (!gIsSpringBoard) return;
    va_list ap;
    va_start(ap, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    NSLog(@"[DuoBar12] %@", msg);
    NSString *line = [NSString stringWithFormat:@"%@ %@\n", [NSDate date], msg];
    NSString *path = @"/var/mobile/duobar12.log";
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
    if (!fh) {
        [line writeToFile:path atomically:NO encoding:NSUTF8StringEncoding error:nil];
        return;
    }
    [fh seekToEndOfFile];
    [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
    [fh closeFile];
}

// Reads an integer-typed ivar by name without KVC exceptions; returns fallback if it is missing.
static long DuoReadInt(id obj, const char *name, long fallback) {
    if (!obj) return fallback;
    Ivar iv = class_getInstanceVariable(object_getClass(obj), name);
    if (!iv) return fallback;
    const char *enc = ivar_getTypeEncoding(iv);
    if (!enc) return fallback;
    uint8_t *base = (uint8_t *)(__bridge void *)obj;
    void *p = base + ivar_getOffset(iv);
    switch (enc[0]) {
        case 'i': return *(int *)p;
        case 'I': return (long)*(unsigned int *)p;
        case 's': return *(short *)p;
        case 'S': return *(unsigned short *)p;
        case 'q': return (long)*(long long *)p;
        case 'Q': return (long)*(unsigned long long *)p;
        case 'c': return *(signed char *)p;
        case 'C': return *(unsigned char *)p;
        case 'B': return *(bool *)p ? 1 : 0;
        default: return fallback;
    }
}

// Fallback when the data-network type ivar cannot be read: reachable without WWAN means Wi-Fi.
static BOOL DuoWiFiReachable(void) {
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_len = sizeof(addr);
    addr.sin_family = AF_INET;
    SCNetworkReachabilityRef r = SCNetworkReachabilityCreateWithAddress(NULL, (const struct sockaddr *)&addr);
    if (!r) return NO;
    SCNetworkReachabilityFlags f = 0;
    BOOL ok = SCNetworkReachabilityGetFlags(r, &f);
    CFRelease(r);
    return ok && (f & kSCNetworkReachabilityFlagsReachable) && !(f & kSCNetworkReachabilityFlagsIsWWAN);
}

// Ask the status bar to re-run item layout (applies size / enable changes without a respring).
static void DuoRefreshStatusBar(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIApplication *app = [UIApplication sharedApplication];
        if (!app) return;
        SEL sbSel = NSSelectorFromString(@"statusBar");
        if (![app respondsToSelector:sbSel]) return;
        id bar = ((id (*)(id, SEL))objc_msgSend)(app, sbSel);
        SEL upd = NSSelectorFromString(@"forceUpdateData:");
        if (bar && [bar respondsToSelector:upd]) {
            ((void (*)(id, SEL, BOOL))objc_msgSend)(bar, upd, YES);
        }
    });
}

static void DuoPrefsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    [[DuoState shared] reloadPrefs];
    [[DuoState shared] notifyChanged];
    DuoRefreshStatusBar();
}

#pragma mark - Battery item: hosts the Duo glyph

%hook UIStatusBarBatteryItemView

%property (nonatomic, strong) DuoGlyphView *duoGlyph;

- (CGFloat)updateContentsAndWidth {
    DuoState *st = [DuoState shared];
    if (!st.enabled) {
        [self.duoGlyph removeFromSuperview];
        return %orig;
    }

    static BOOL logged = NO;
    if (!logged) {
        logged = YES;
        DuoLog(@"battery item active, bounds=%@ hasForegroundStyle=%d", NSStringFromCGRect(self.bounds),
               (int)[self respondsToSelector:NSSelectorFromString(@"foregroundStyle")]);
    }

    DuoGlyphView *g = self.duoGlyph;
    if (!g) {
        g = [[DuoGlyphView alloc] initWithFrame:self.bounds];
        self.duoGlyph = g;
    }
    if (g.superview != self) [self addSubview:g];
    g.frame = self.bounds;
    [g setNeedsDisplay];
    return [DuoGlyphView preferredWidth];
}

- (void)layoutSubviews {
    %orig;
    DuoGlyphView *g = self.duoGlyph;
    if (g.superview == self) g.frame = self.bounds;
}

%end

#pragma mark - Items that collapse into the glyph

%hook UIStatusBarBatteryPercentItemView

- (CGFloat)updateContentsAndWidth {
    if (![DuoState shared].enabled) return %orig;
    return 0.0;
}

%end

%hook UIStatusBarSignalStrengthItemView

- (BOOL)updateForNewData:(id)data actions:(int)actions {
    BOOL r = %orig;
    long bars = DuoReadInt(self, "_signalStrengthBars", -1);

    static BOOL logged = NO;
    if (!logged) {
        logged = YES;
        DuoLog(@"signal item: _signalStrengthBars=%ld", bars);
    }

    DuoState *st = [DuoState shared];
    if (bars != st.cellBars) {
        st.cellBars = bars;
        [st notifyChanged];
    }
    return r;
}

- (CGFloat)updateContentsAndWidth {
    if (![DuoState shared].enabled) return %orig;
    return 0.0;
}

%end

%hook UIStatusBarDataNetworkItemView

- (BOOL)updateForNewData:(id)data actions:(int)actions {
    BOOL r = %orig;
    long type = DuoReadInt(self, "_dataNetworkType", -1);
    long bars = DuoReadInt(self, "_wifiStrengthBars", 0);
    BOOL wifi = (type >= 0) ? (type == 5) : DuoWiFiReachable();
    if (bars < 0) bars = 0;
    if (bars > 3) bars = 3;

    static BOOL logged = NO;
    if (!logged) {
        logged = YES;
        DuoLog(@"data item: _dataNetworkType=%ld _wifiStrengthBars=%ld wifi=%d", type, bars, (int)wifi);
    }

    DuoState *st = [DuoState shared];
    if (wifi != st.wifiVisible || bars != st.wifiBars) {
        st.wifiVisible = wifi;
        st.wifiBars = bars;
        [st notifyChanged];
    }
    return r;
}

- (CGFloat)updateContentsAndWidth {
    if (![DuoState shared].enabled) return %orig;
    return 0.0;
}

%end

%ctor {
    @autoreleasepool {
        (void)[DuoState shared];
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, DuoPrefsChanged,
                                        DUO_PREFS_NOTIFICATION, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        gIsSpringBoard = [[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"];
        DuoLog(@"loaded; classes battery=%d percent=%d signal=%d data=%d",
               (int)(NSClassFromString(@"UIStatusBarBatteryItemView") != nil),
               (int)(NSClassFromString(@"UIStatusBarBatteryPercentItemView") != nil),
               (int)(NSClassFromString(@"UIStatusBarSignalStrengthItemView") != nil),
               (int)(NSClassFromString(@"UIStatusBarDataNetworkItemView") != nil));
        %init;
    }
}
