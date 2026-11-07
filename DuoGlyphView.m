#import "DuoGlyphView.h"

NSString *const DuoStateDidChangeNotification = @"local.duobar.ios12.stateChanged";

static id DuoPref(NSString *key) {
    CFPropertyListRef v = CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)DUO_DOMAIN);
    return CFBridgingRelease(v);
}

@implementation DuoState

+ (instancetype)shared {
    static DuoState *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        s = [DuoState new];
        s.cellBars = -1;
        s.wifiBars = 0;
        s.wifiVisible = NO;
        [s reloadPrefs];
    });
    return s;
}

- (void)reloadPrefs {
    CFPreferencesAppSynchronize((__bridge CFStringRef)DUO_DOMAIN);
    id e = DuoPref(@"Enabled");
    id p = DuoPref(@"ShowPercent");
    id z = DuoPref(@"SizeScale");
    id c = DuoPref(@"ColorMode");
    self.enabled = e ? [e boolValue] : YES;
    self.showPercent = p ? [p boolValue] : YES;
    NSInteger size = z ? (NSInteger)lround([z doubleValue]) : 100;
    self.sizePercent = MAX(70, MIN(140, size));
    self.colorMode = c ? [c integerValue] : 0;
}

- (void)notifyChanged {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DuoStateDidChangeNotification object:nil];
    });
}

@end

// Design box the glyph is drawn in; scaled to the real size at draw time.
static const CGFloat kBox = 24.0;

@implementation DuoGlyphView

+ (CGFloat)scale {
    return (CGFloat)[DuoState shared].sizePercent / 100.0;
}

+ (CGFloat)glyphSide {
    return 18.0 * [self scale];
}

+ (UIFont *)percentFont {
    return [UIFont systemFontOfSize:11.0 * [self scale] weight:UIFontWeightSemibold];
}

+ (CGFloat)percentWidth {
    // Measured on the widest value so the status bar layout never shifts while charging.
    return ceil([@"100%" sizeWithAttributes:@{NSFontAttributeName: [self percentFont]}].width);
}

+ (CGFloat)preferredWidth {
    CGFloat w = [self glyphSide] + 2.0;
    if ([DuoState shared].showPercent) w += [self percentWidth] + 3.0 * [self scale];
    return ceil(w);
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
        self.contentMode = UIViewContentModeRedraw;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(refresh) name:UIDeviceBatteryLevelDidChangeNotification object:nil];
        [nc addObserver:self selector:@selector(refresh) name:UIDeviceBatteryStateDidChangeNotification object:nil];
        [nc addObserver:self selector:@selector(refresh) name:NSProcessInfoPowerStateDidChangeNotification object:nil];
        [nc addObserver:self selector:@selector(refresh) name:DuoStateDidChangeNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)refresh {
    [self setNeedsDisplay];
}

- (UIColor *)foregroundColor {
    NSInteger mode = [DuoState shared].colorMode;
    if (mode == 1) return [UIColor whiteColor];
    if (mode == 2) return [UIColor blackColor];

    // Auto: ask the native item view's foreground style, then fall back to the status bar style.
    UIView *item = self.superview;
    if (item) {
        @try {
            id style = [item valueForKey:@"foregroundStyle"];
            if ([style respondsToSelector:@selector(tintColor)]) {
                UIColor *c = [style performSelector:@selector(tintColor)];
                if ([c isKindOfClass:[UIColor class]]) return c;
            }
        } @catch (__unused NSException *e) {}
    }
    UIApplication *app = [UIApplication sharedApplication];
    return (app && app.statusBarStyle == UIStatusBarStyleLightContent) ? [UIColor whiteColor] : [UIColor blackColor];
}

- (void)drawRect:(CGRect)rect {
    DuoState *st = [DuoState shared];
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return;

    UIDevice *dev = [UIDevice currentDevice];
    float lvl = dev.batteryLevel;
    if (lvl < 0.0f) lvl = 1.0f;
    if (lvl > 1.0f) lvl = 1.0f;
    UIDeviceBatteryState bs = dev.batteryState;
    BOOL charging = (bs == UIDeviceBatteryStateCharging);
    BOOL plugged = charging || (bs == UIDeviceBatteryStateFull);
    BOOL lowPower = [[NSProcessInfo processInfo] isLowPowerModeEnabled];

    UIColor *fg = [self foregroundColor];
    UIColor *accent = fg;
    if (plugged) accent = [UIColor colorWithRed:0.30 green:0.85 blue:0.39 alpha:1.0];
    else if (lowPower) accent = [UIColor colorWithRed:1.0 green:0.80 blue:0.0 alpha:1.0];
    else if (lvl <= 0.20f) accent = [UIColor colorWithRed:1.0 green:0.23 blue:0.19 alpha:1.0];

    CGFloat s = [DuoGlyphView scale];
    CGFloat side = [DuoGlyphView glyphSide];
    CGRect b = self.bounds;
    CGFloat gx = CGRectGetMaxX(b) - 1.0 - side;
    CGFloat gy = floor(CGRectGetMidY(b) - side / 2.0);

    // ---- Percentage text (left of the ring) and charging bolt -------------------------------
    CGFloat leftEdge = gx; // x where the next element to the left must end
    if (st.showPercent) {
        UIFont *font = [DuoGlyphView percentFont];
        NSMutableParagraphStyle *ps = [NSMutableParagraphStyle new];
        ps.alignment = NSTextAlignmentRight;
        NSDictionary *attrs = @{NSFontAttributeName: font, NSForegroundColorAttributeName: fg, NSParagraphStyleAttributeName: ps};
        NSString *txt = [NSString stringWithFormat:@"%d%%", (int)lroundf(lvl * 100.0f)];
        CGFloat pw = [DuoGlyphView percentWidth];
        CGFloat th = ceil(font.lineHeight);
        CGRect tr = CGRectMake(gx - 3.0 * s - pw, floor(CGRectGetMidY(b) - th / 2.0), pw, th);
        [txt drawInRect:tr withAttributes:attrs];
        leftEdge = CGRectGetMinX(tr);
    }
    if (charging) {
        CGFloat bx = leftEdge - 7.0 * s - 1.0;
        CGFloat by = CGRectGetMidY(b) - 5.2 * s;
        UIBezierPath *bolt = [UIBezierPath bezierPath];
        [bolt moveToPoint:CGPointMake(bx + 4.2 * s, by)];
        [bolt addLineToPoint:CGPointMake(bx, by + 5.8 * s)];
        [bolt addLineToPoint:CGPointMake(bx + 2.5 * s, by + 5.8 * s)];
        [bolt addLineToPoint:CGPointMake(bx + 1.6 * s, by + 10.4 * s)];
        [bolt addLineToPoint:CGPointMake(bx + 6.2 * s, by + 4.2 * s)];
        [bolt addLineToPoint:CGPointMake(bx + 3.6 * s, by + 4.2 * s)];
        [bolt closePath];
        [accent setFill];
        [bolt fill];
    }

    // ---- The glyph itself, drawn in a 24x24 design box ---------------------------------------
    CGContextSaveGState(ctx);
    CGContextTranslateCTM(ctx, gx, gy);
    CGContextScaleCTM(ctx, side / kBox, side / kBox);

    UIColor *dim = [fg colorWithAlphaComponent:0.28];
    CGPoint c = CGPointMake(12.0, 12.0);
    CGFloat R = 10.2;
    CGFloat gap = 0.85; // half-angle of the opening at the bottom
    CGFloat a0 = M_PI_2 + gap;
    CGFloat a1 = 2.0 * M_PI + M_PI_2 - gap;

    // Battery ring: open at the bottom, fills clockwise from the lower-left end.
    UIBezierPath *track = [UIBezierPath bezierPathWithArcCenter:c radius:R startAngle:a0 endAngle:a1 clockwise:YES];
    track.lineWidth = 2.4;
    track.lineCapStyle = kCGLineCapRound;
    [dim setStroke];
    [track stroke];

    CGFloat frac = MAX(0.02, MIN(1.0, (CGFloat)lvl));
    UIBezierPath *fill = [UIBezierPath bezierPathWithArcCenter:c radius:R startAngle:a0 endAngle:a0 + (a1 - a0) * frac clockwise:YES];
    fill.lineWidth = 2.4;
    fill.lineCapStyle = kCGLineCapRound;
    [accent setStroke];
    [fill stroke];

    // Wi-Fi in the center: dot plus up to three arcs.
    if (st.wifiVisible) {
        CGPoint wc = CGPointMake(12.0, 15.4);
        [fg setFill];
        [[UIBezierPath bezierPathWithArcCenter:wc radius:1.15 startAngle:0 endAngle:2.0 * M_PI clockwise:YES] fill];
        CGFloat radii[3] = {2.8, 5.1, 7.4};
        for (int i = 0; i < 3; i++) {
            UIBezierPath *arc = [UIBezierPath bezierPathWithArcCenter:wc radius:radii[i] startAngle:5.0 * M_PI_4 endAngle:7.0 * M_PI_4 clockwise:YES];
            arc.lineWidth = 1.5;
            arc.lineCapStyle = kCGLineCapRound;
            [(i < st.wifiBars ? fg : dim) setStroke];
            [arc stroke];
        }
    }

    // Cellular: four dots in the opening of the ring.
    NSInteger bars = st.cellBars;
    NSInteger lit = bars <= 0 ? 0 : MIN(4, (NSInteger)lround(bars * 4.0 / 5.0));
    if (bars > 0 && lit == 0) lit = 1;
    for (int i = 0; i < 4; i++) {
        CGFloat x = 12.0 + (i - 1.5) * 3.4;
        UIBezierPath *dot = [UIBezierPath bezierPathWithArcCenter:CGPointMake(x, 21.2) radius:1.15 startAngle:0 endAngle:2.0 * M_PI clockwise:YES];
        [(i < lit ? fg : dim) setFill];
        [dot fill];
    }

    CGContextRestoreGState(ctx);
}

@end
