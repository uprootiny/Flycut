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
    // Map normalized X/Y (-1 to 1) to UI state or LLM params
    CGFloat alpha = 0.5 + (y * 0.5); // Tilt affects transparency/perspective
    [self.animator setAlphaValue:MAX(0.2, alpha)];
    
    // Physical feedback: Move the window slightly based on 'drift'
    NSRect currentFrame = self.frame;
    currentFrame.origin.x += x * 5.0;
    currentFrame.origin.y += y * 5.0;
    [self setFrame:currentFrame display:YES];
}

@end
