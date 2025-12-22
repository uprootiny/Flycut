//
//  BezelWindow+QuicksilverStyle.m
//  Flycut
//
//  Quicksilver-style bezel modifications
//  Apply these changes to UI/BezelWindow.m
//

/*
 * =============================================================================
 * MODIFICATION POINTS FOR QUICKSILVER-STYLE BEZEL
 * =============================================================================
 *
 * This file documents the changes needed to transform Flycut's bezel into
 * a Quicksilver-style floating popup with:
 *   - Vibrancy/blur backdrop
 *   - Larger corner radius
 *   - Icon-centric layout
 *   - Search/filter capability
 *   - Smooth animations
 *
 * =============================================================================
 */

#pragma mark - 1. NSVisualEffectView Backdrop

/*
 * In BezelWindow.m, find the initWithContentRect: method and add:
 */

// BEFORE (existing code):
// [self setBackgroundColor:[NSColor clearColor]];

// AFTER (add visual effect view):
/*
- (void)setupVisualEffect {
    // Create vibrancy effect
    NSVisualEffectView *effectView = [[NSVisualEffectView alloc] 
        initWithFrame:self.contentView.bounds];
    
    // Use HUD window material for dark semi-transparent look
    effectView.material = NSVisualEffectMaterialHUDWindow;
    
    // Or for even darker: NSVisualEffectMaterialDark
    // Or for Quicksilver menu style: NSVisualEffectMaterialMenu
    
    effectView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    effectView.state = NSVisualEffectStateActive;
    
    // Rounded corners via layer
    effectView.wantsLayer = YES;
    effectView.layer.cornerRadius = 20.0;  // Larger than default
    effectView.layer.masksToBounds = YES;
    
    // Auto-resize with window
    effectView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    
    [self.contentView addSubview:effectView positioned:NSWindowBelow relativeTo:nil];
    
    // Store reference for later
    self.visualEffectView = effectView;
}
*/

#pragma mark - 2. Corner Radius Enhancement

/*
 * If using layer-backed contentView, modify the corner radius:
 */

/*
- (void)configureWindowAppearance {
    // Make content view layer-backed
    self.contentView.wantsLayer = YES;
    self.contentView.layer.cornerRadius = 20.0;
    self.contentView.layer.masksToBounds = YES;
    
    // Add subtle shadow
    self.hasShadow = YES;
    
    // Set window level for floating
    self.level = NSFloatingWindowLevel;
    
    // Prevent becoming key window (optional)
    // self.canBecomeKeyWindow = NO;
}
*/

#pragma mark - 3. Animation Enhancements

/*
 * Replace existing show/hide with animated versions:
 */

/*
- (void)showWithQuicksilverAnimation {
    // Start state: invisible, slightly smaller
    self.alphaValue = 0.0;
    NSRect targetFrame = self.frame;
    NSRect startFrame = NSInsetRect(targetFrame, 20, 20);
    [self setFrame:startFrame display:NO];
    
    // Show window
    [self makeKeyAndOrderFront:nil];
    
    // Animate to full size and opacity
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.15;
        context.timingFunction = [CAMediaTimingFunction 
            functionWithName:kCAMediaTimingFunctionEaseOut];
        
        self.animator.alphaValue = 1.0;
        [self.animator setFrame:targetFrame display:YES];
    }];
}

- (void)hideWithQuicksilverAnimation {
    NSRect startFrame = self.frame;
    NSRect endFrame = NSInsetRect(startFrame, 20, 20);
    
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.12;
        context.timingFunction = [CAMediaTimingFunction 
            functionWithName:kCAMediaTimingFunctionEaseIn];
        
        self.animator.alphaValue = 0.0;
        [self.animator setFrame:endFrame display:YES];
    } completionHandler:^{
        [self orderOut:nil];
        // Reset frame for next show
        [self setFrame:startFrame display:NO];
    }];
}
*/

#pragma mark - 4. Search Field Integration

/*
 * Add search field to bezel for filtering clips:
 */

/*
@interface BezelWindow ()
@property (nonatomic, strong) NSTextField *searchField;
@property (nonatomic, strong) NSString *searchQuery;
@end

- (void)setupSearchField {
    NSRect searchFrame = NSMakeRect(20, 10, self.frame.size.width - 40, 24);
    
    self.searchField = [[NSTextField alloc] initWithFrame:searchFrame];
    self.searchField.placeholderString = @"Filter clips...";
    self.searchField.bezeled = NO;
    self.searchField.drawsBackground = NO;
    self.searchField.textColor = [NSColor whiteColor];
    self.searchField.font = [NSFont systemFontOfSize:14];
    self.searchField.delegate = self;
    self.searchField.focusRingType = NSFocusRingTypeNone;
    
    // Add to view hierarchy
    [self.contentView addSubview:self.searchField];
    
    // Initially hidden
    self.searchField.hidden = YES;
}

- (void)controlTextDidChange:(NSNotification *)notification {
    if (notification.object == self.searchField) {
        self.searchQuery = self.searchField.stringValue;
        // Notify delegate/controller to filter
        [[NSNotificationCenter defaultCenter] 
            postNotificationName:@"BezelSearchQueryChanged"
            object:self
            userInfo:@{@"query": self.searchQuery ?: @""}];
    }
}

// Show search field when user starts typing
- (void)keyDown:(NSEvent *)event {
    unichar c = [[event charactersIgnoringModifiers] characterAtIndex:0];
    
    // If alphanumeric, activate search
    if (isalnum(c)) {
        self.searchField.hidden = NO;
        [self.searchField becomeFirstResponder];
        // Forward the keystroke
        [self.searchField.currentEditor insertText:event.characters];
    } else {
        [super keyDown:event];
    }
}
*/

#pragma mark - 5. Icon-Centric Layout

/*
 * Modify XIB or programmatically create icon-centric view:
 */

/*
- (void)setupIconCentricLayout {
    // Large icon view (128x128)
    NSImageView *iconView = [[NSImageView alloc] 
        initWithFrame:NSMakeRect(
            (self.frame.size.width - 128) / 2,
            self.frame.size.height - 150,
            128, 128)];
    iconView.imageScaling = NSImageScaleProportionallyUpOrDown;
    
    // Preview text below icon
    NSTextField *previewLabel = [[NSTextField alloc] 
        initWithFrame:NSMakeRect(
            20,
            self.frame.size.height - 200,
            self.frame.size.width - 40,
            40)];
    previewLabel.bezeled = NO;
    previewLabel.drawsBackground = NO;
    previewLabel.editable = NO;
    previewLabel.selectable = NO;
    previewLabel.textColor = [NSColor whiteColor];
    previewLabel.alignment = NSTextAlignmentCenter;
    previewLabel.font = [NSFont systemFontOfSize:14];
    previewLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    
    // Position indicator at bottom
    NSTextField *positionLabel = [[NSTextField alloc]
        initWithFrame:NSMakeRect(
            20,
            40,
            self.frame.size.width - 40,
            20)];
    positionLabel.bezeled = NO;
    positionLabel.drawsBackground = NO;
    positionLabel.editable = NO;
    positionLabel.selectable = NO;
    positionLabel.textColor = [[NSColor whiteColor] colorWithAlphaComponent:0.6];
    positionLabel.alignment = NSTextAlignmentCenter;
    positionLabel.font = [NSFont systemFontOfSize:12];
    
    [self.contentView addSubview:iconView];
    [self.contentView addSubview:previewLabel];
    [self.contentView addSubview:positionLabel];
    
    self.iconView = iconView;
    self.previewLabel = previewLabel;
    self.positionLabel = positionLabel;
}

- (void)updateWithClipping:(FlycutClipping *)clipping atPosition:(NSInteger)pos ofTotal:(NSInteger)total {
    // Get source app icon
    NSImage *appIcon = [[NSWorkspace sharedWorkspace] 
        iconForFile:[[NSWorkspace sharedWorkspace] 
            absolutePathForAppBundleWithIdentifier:clipping.sourceAppIdentifier]];
    if (!appIcon) {
        appIcon = [NSImage imageNamed:NSImageNameApplicationIcon];
    }
    self.iconView.image = appIcon;
    
    // Preview text (first 100 chars)
    NSString *preview = clipping.contents;
    if (preview.length > 100) {
        preview = [[preview substringToIndex:100] stringByAppendingString:@"..."];
    }
    self.previewLabel.stringValue = preview ?: @"";
    
    // Position
    self.positionLabel.stringValue = [NSString stringWithFormat:@"%ld of %ld", pos + 1, total];
}
*/

#pragma mark - 6. Color Scheme (Quicksilver Dark)

/*
 * Define Quicksilver-inspired color constants:
 */

/*
static NSColor *QSBezelBackgroundColor(void) {
    return [NSColor colorWithCalibratedWhite:0.1 alpha:0.9];
}

static NSColor *QSBezelTextColor(void) {
    return [NSColor whiteColor];
}

static NSColor *QSBezelSecondaryTextColor(void) {
    return [[NSColor whiteColor] colorWithAlphaComponent:0.6];
}

static NSColor *QSBezelSelectionColor(void) {
    return [NSColor colorWithCalibratedRed:0.3 green:0.5 blue:0.8 alpha:0.8];
}

static CGFloat QSBezelCornerRadius(void) {
    return 20.0;
}
*/

#pragma mark - 7. Complete Integration Example

/*
 * Full initialization integrating all features:
 */

/*
- (instancetype)initWithContentRect:(NSRect)contentRect
                          styleMask:(NSWindowStyleMask)style
                            backing:(NSBackingStoreType)backingStoreType
                              defer:(BOOL)flag {
    self = [super initWithContentRect:contentRect
                            styleMask:NSWindowStyleMaskBorderless
                              backing:backingStoreType
                                defer:flag];
    if (self) {
        // Basic window setup
        [self setBackgroundColor:[NSColor clearColor]];
        [self setOpaque:NO];
        [self setHasShadow:YES];
        [self setLevel:NSFloatingWindowLevel];
        [self setCollectionBehavior:
            NSWindowCollectionBehaviorCanJoinAllSpaces | 
            NSWindowCollectionBehaviorTransient];
        
        // Quicksilver-style enhancements
        [self setupVisualEffect];
        [self setupIconCentricLayout];
        [self setupSearchField];
        [self configureWindowAppearance];
    }
    return self;
}
*/
