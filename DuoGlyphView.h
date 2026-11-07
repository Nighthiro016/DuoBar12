#import <UIKit/UIKit.h>

#define DUO_DOMAIN @"local.duobar.ios12"
#define DUO_PREFS_NOTIFICATION CFSTR("local.duobar.ios12/prefs")

extern NSString *const DuoStateDidChangeNotification;

// Shared, process-local state: preferences plus signal data scraped from the native status bar items.
@interface DuoState : NSObject
+ (instancetype)shared;
@property (atomic, assign) BOOL enabled;
@property (atomic, assign) BOOL showPercent;
@property (atomic, assign) NSInteger sizePercent;   // 70...140
@property (atomic, assign) NSInteger colorMode;     // 0 auto, 1 white, 2 black
@property (atomic, assign) NSInteger cellBars;      // raw legacy bars, 0...5, -1 unknown
@property (atomic, assign) NSInteger wifiBars;      // raw legacy bars, 0...3
@property (atomic, assign) BOOL wifiVisible;
- (void)reloadPrefs;
- (void)notifyChanged;
@end

@interface DuoGlyphView : UIView
+ (CGFloat)preferredWidth;
@end
