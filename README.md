# Flycut Fork - With Quicksilver-Style Floating Popup

Personal fork of [Flycut](https://github.com/TermiT/Flycut) clipboard manager, extended with a Quicksilver-style floating bezel interface.

## Overview

```
┌─────────────────────────────────────────────────────────────────┐
│  GOALS                                                          │
├─────────────────────────────────────────────────────────────────┤
│  1. Build Flycut via GitHub Actions (no local Xcode required)   │
│  2. Produce unsigned .app downloadable from GitHub Releases     │
│  3. Add Quicksilver-style floating popup interface              │
│  4. Personal scratching of itch                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Quick Start

### Option A: Use Pre-built Releases

1. Go to [Releases](../../releases)
2. Download `Flycut.dmg` or `Flycut.zip`
3. Extract and move to `/Applications`
4. On first launch: Right-click → Open (to bypass Gatekeeper for unsigned app)
5. Grant Accessibility permissions in System Preferences → Privacy & Security → Accessibility

### Option B: Build via GitHub Actions

1. Fork this repository
2. Push any commit (or create a tag `v*` for a release)
3. Go to Actions tab → download build artifacts

### Option C: Build Locally

```bash
# Clone
git clone https://github.com/YOUR_USERNAME/flycut-fork.git
cd flycut-fork

# Build unsigned
xcodebuild \
  -project Flycut.xcodeproj \
  -scheme Flycut \
  -configuration Release \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO

# App will be at: build/Build/Products/Release/Flycut.app
```

## Architecture Notes

### Existing Flycut Bezel System

```
┌────────────────────────────────────────────────────────────────────┐
│  FLYCUT BEZEL ARCHITECTURE                                         │
├────────────────────────────────────────────────────────────────────┤
│                                                                    │
│  AppController.m                                                   │
│  ├── bezel : BezelWindow*        ← The floating window             │
│  ├── showBezel                   ← Display with animation          │
│  ├── hideBezel                   ← Hide with animation             │
│  └── fakeCommandV                ← Paste via CGEvent               │
│                                                                    │
│  UI/BezelWindow.{h,m}                                              │
│  ├── NSWindow subclass           ← Borderless, floating            │
│  ├── RoundRecBezierPath          ← Rounded corners                 │
│  └── setCharString:              ← Position indicator "3 of 42"    │
│                                                                    │
│  UI/FlycutBezel.xib                                                │
│  └── Interface Builder layout                                      │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

### Quicksilver-Style Enhancements

The Quicksilver "Bezel" interface characteristics:
- **Semi-transparent dark background** with blur (NSVisualEffectView)
- **Rounded corners** (larger radius than standard)
- **Large centered icon** for the current item
- **Minimal text** - just the essential info
- **Smooth animations** - fade in/out, possible scale
- **Search/filter bar** at bottom when typing

```
┌─────────────────────────────────────────────────────┐
│                                                     │
│              ┌───────────────────┐                  │
│              │                   │                  │
│              │    [app icon]     │                  │
│              │                   │                  │
│              └───────────────────┘                  │
│                                                     │
│           "Copied text preview..."                  │
│                                                     │
│              ─────────────────────                  │
│              [search filter box]                    │
│                                                     │
│                   3 of 42                           │
│                                                     │
└─────────────────────────────────────────────────────┘
        Quicksilver-style Bezel
```

## Modification Targets

### Files to Modify/Create

```
┌─────────────────────────────────────────────────────────────────────┐
│  MODIFICATION PLAN                                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  1. UI/BezelWindow.m                                                │
│     • Add NSVisualEffectView for blur backdrop                      │
│     • Increase corner radius                                        │
│     • Add scaling animation on show/hide                            │
│                                                                     │
│  2. UI/FlycutBezel.xib                                              │
│     • Rearrange layout for larger icon-centric design               │
│     • Add search text field                                         │
│                                                                     │
│  3. AppController.m                                                 │
│     • Wire up search/filter functionality                           │
│     • Add keyboard shortcuts within bezel                           │
│                                                                     │
│  4. Resources/                                                      │
│     • Custom icons/assets if needed                                 │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### NSVisualEffectView Integration

```objc
// In BezelWindow.m - initWithContentRect:
NSVisualEffectView *effectView = [[NSVisualEffectView alloc] initWithFrame:self.contentView.bounds];
effectView.material = NSVisualEffectMaterialHUDWindow;
effectView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
effectView.state = NSVisualEffectStateActive;
effectView.wantsLayer = YES;
effectView.layer.cornerRadius = 20.0;
effectView.layer.masksToBounds = YES;
[self.contentView addSubview:effectView positioned:NSWindowBelow relativeTo:nil];
```

### Animation Enhancement

```objc
// Fade + Scale animation
- (void)showBezelWithAnimation {
    self.alphaValue = 0.0;
    [self setFrame:NSInsetRect(self.frame, 20, 20) display:NO];
    [self makeKeyAndOrderFront:nil];
    
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.15;
        context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        self.animator.alphaValue = 1.0;
        [self.animator setFrame:NSInsetRect(self.frame, -20, -20) display:YES];
    }];
}
```

## System Requirements

| Component         | Requirement                |
|-------------------|----------------------------|
| macOS             | 10.15+ (Catalina)          |
| Accessibility     | Must be granted            |
| Architecture      | Universal (Intel + ARM64)  |

## GitHub Actions Build Matrix

The workflow builds on `macos-14` (Apple Silicon) runner:
- Produces universal binary via `ONLY_ACTIVE_ARCH=NO`
- Unsigned (bypass with right-click → Open)
- Artifacts: `.dmg`, `.zip`, and raw `.app` bundle

## License

MIT License (inherited from Flycut)

---

## TODO

- [ ] Fork TermiT/Flycut
- [ ] Add this workflow
- [ ] Test build succeeds
- [ ] Implement NSVisualEffectView backdrop
- [ ] Implement search/filter in bezel
- [ ] Add animation polish
- [ ] Test on old Mac (specify your macOS version)
