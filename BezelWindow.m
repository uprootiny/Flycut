#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

@interface BezelWindow : NSWindow
@property (nonatomic, strong) NSVisualEffectView *visualEffectView;
@property (nonatomic, strong) NSTextField *searchField;
@property (nonatomic, strong) NSImageView *iconView;
@property (nonatomic, strong) NSTextField *previewLabel;
@property (nonatomic, strong) NSTextField *positionLabel;
@end

@implementation BezelWindow

- (instancetype)initWithContentRect:(NSRect)contentRect
                          styleMask:(NSWindowStyleMask)style
                            backing:(NSBackingStoreType)backingStoreType
                              defer:(BOOL)flag {
    self = [super initWithContentRect:contentRect
                            styleMask:NSWindowStyleMaskBorderless
                              backing:backingStoreType
                                defer:flag];
    if (self) {
        [self setBackgroundColor:[NSColor clearColor]];
        [self setOpaque:NO];
        [self setHasShadow:YES];
        [self setLevel:NSFloatingWindowLevel];
        
        [self setupVisualEffect];
        [self setupIconCentricLayout];
        
        // Ensure robust layer-backed rendering
        self.contentView.wantsLayer = YES;
        self.contentView.layer.cornerRadius = 20.0;
        self.contentView.layer.masksToBounds = YES;
    }
    return self;
}

- (void)setupVisualEffect {
    _visualEffectView = [[NSVisualEffectView alloc] initWithFrame:self.contentView.bounds];
    _visualEffectView.material = NSVisualEffectMaterialHUDWindow;
    _visualEffectView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    _visualEffectView.state = NSVisualEffectStateActive;
    _visualEffectView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    
    _visualEffectView.wantsLayer = YES;
    _visualEffectView.layer.cornerRadius = 20.0;
    
    [self.contentView addSubview:_visualEffectView positioned:NSWindowBelow relativeTo:nil];
}

- (void)setupIconCentricLayout {
    // Large Central Icon
    _iconView = [[NSImageView alloc] initWithFrame:NSMakeRect((self.frame.size.width - 128)/2, self.frame.size.height - 160, 128, 128)];
    _iconView.imageScaling = NSImageScaleProportionallyUpOrDown;
    
    // Preview Label
    _previewLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, self.frame.size.height - 220, self.frame.size.width - 40, 50)];
    [_previewLabel setBezeled:NO];
    [_previewLabel setDrawsBackground:NO];
    [_previewLabel setEditable:NO];
    [_previewLabel setTextColor:[NSColor whiteColor]];
    [_previewLabel setAlignment:NSTextAlignmentCenter];
    [_previewLabel setFont:[NSFont systemFontOfSize:16 weight:NSFontWeightMedium]];
    
    [self.contentView addSubview:_iconView];
    [self.contentView addSubview:_previewLabel];
}

// Robust Mapping: Gimbal (Mouse Position) to Semantic Space
- (void)updateWithGimbalX:(CGFloat)x y:(CGFloat)y {
    // Clamp inputs to prevent overflow/unexpected behavior
    CGFloat clampedX = MAX(-1.0, MIN(1.0, x));
    CGFloat clampedY = MAX(-1.0, MIN(1.0, y));

    // Map normalized X/Y (-1 to 1) to UI state
    CGFloat targetAlpha = 0.5 + (clampedY * 0.5);
    [self.animator setAlphaValue:MAX(0.2, MIN(1.0, targetAlpha))];

    // Prevent "Screen Drift" - Keep window within visible screen bounds
    NSRect currentFrame = self.frame;
    NSRect screenFrame = [[NSScreen mainScreen] visibleFrame];

    CGFloat driftX = clampedX * 10.0;
    CGFloat driftY = clampedY * 10.0;

    NSRect targetFrame = NSOffsetRect(currentFrame, driftX, driftY);

    if (NSContainsRect(screenFrame, targetFrame)) {
        [self setFrame:targetFrame display:YES animate:NO];
    }
}

@end
