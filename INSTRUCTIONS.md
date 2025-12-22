# Forking and Building Flycut - Step by Step

## Step 1: Fork on GitHub

1. Go to https://github.com/TermiT/Flycut
2. Click "Fork" button (top right)
3. Select your account as destination
4. You now have: `https://github.com/YOUR_USERNAME/Flycut`

## Step 2: Clone Locally (Optional)

```bash
git clone https://github.com/YOUR_USERNAME/Flycut.git
cd Flycut
```

## Step 3: Add GitHub Actions Workflow

Create the file `.github/workflows/build.yml`:

**Via GitHub Web UI:**
1. Go to your fork
2. Click "Add file" → "Create new file"
3. Name it: `.github/workflows/build.yml`
4. Paste the workflow content (see below)
5. Commit to main branch

**Via Command Line:**
```bash
mkdir -p .github/workflows
# Copy the build.yml from this repo
cp path/to/build.yml .github/workflows/
git add .github/workflows/build.yml
git commit -m "Add GitHub Actions build workflow"
git push origin main
```

## Step 4: Trigger Build

### Automatic:
- Any push to `main` triggers the build
- Creating a tag `v*` (e.g., `v1.0.0`) creates a release

### Manual:
1. Go to Actions tab in your fork
2. Select "Build Flycut" workflow
3. Click "Run workflow"

## Step 5: Download Your Build

1. Go to Actions tab
2. Click on the completed workflow run
3. Scroll to "Artifacts" section
4. Download:
   - `Flycut-dmg` - Disk image
   - `Flycut-zip` - Zipped app
   - `Flycut-app` - Raw app bundle

## Step 6: Install on Your Mac

```bash
# Extract
unzip Flycut.zip

# Move to Applications
mv Flycut.app /Applications/

# First launch (bypass Gatekeeper for unsigned app)
# Right-click Flycut.app → Open → Open anyway

# Grant accessibility
# System Preferences → Privacy & Security → Accessibility → Add Flycut
```

---

## Creating a Release

To create an automatic release with downloadable binaries:

```bash
# Tag your commit
git tag v1.0.0
git push origin v1.0.0

# GitHub Actions will:
# 1. Build the app
# 2. Create a GitHub Release
# 3. Attach Flycut.dmg and Flycut.zip
```

---

## Customization: Quicksilver-Style Popup

After basic build works, add our enhancements:

### A. Modify BezelWindow.m

Location: `UI/BezelWindow.m`

Add NSVisualEffectView for blur effect:
```objc
// In initWithContentRect: after [self setBackgroundColor:[NSColor clearColor]];

NSVisualEffectView *effectView = [[NSVisualEffectView alloc] 
    initWithFrame:self.contentView.bounds];
effectView.material = NSVisualEffectMaterialHUDWindow;
effectView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
effectView.state = NSVisualEffectStateActive;
effectView.wantsLayer = YES;
effectView.layer.cornerRadius = 20.0;
effectView.layer.masksToBounds = YES;
effectView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
[self.contentView addSubview:effectView positioned:NSWindowBelow relativeTo:nil];
```

### B. Add Animation

In AppController.m, find `showBezel` method:
```objc
// Replace immediate show with animation
[NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
    context.duration = 0.15;
    context.timingFunction = [CAMediaTimingFunction 
        functionWithName:kCAMediaTimingFunctionEaseOut];
    bezel.animator.alphaValue = 1.0;
}];
```

### C. Add Search Filter

1. Add NSTextField to BezelWindow
2. Wire up delegate for text changes
3. Filter displayed clippings based on search

See `patches/BezelWindow+QuicksilverStyle.m` for complete code.

---

## macOS Version Compatibility

| Your macOS | Works? | Notes |
|------------|--------|-------|
| 10.15+     | ✅     | Full support |
| 10.14      | ✅     | DRM-free version |
| 10.13-     | ⚠️     | May need older Xcode |

For older macOS (10.13 and below):
1. May need to adjust deployment target in Xcode project
2. Use `xcodebuild` with `-sdk macosx10.13`

---

## Troubleshooting

### Build fails with "code signing" error
Ensure these flags are set:
```
CODE_SIGN_IDENTITY=""
CODE_SIGNING_REQUIRED=NO
CODE_SIGNING_ALLOWED=NO
DEVELOPMENT_TEAM=""
```

### App won't open ("damaged" or "unidentified developer")
```bash
# Remove quarantine attribute
xattr -d com.apple.quarantine /Applications/Flycut.app
```

### Accessibility permission not working
1. Remove Flycut from Accessibility list
2. Quit Flycut completely
3. Re-add to Accessibility
4. Relaunch

### Build works locally but fails in GitHub Actions
- Check Xcode version in workflow (`macos-14` uses latest Xcode)
- May need to specify scheme explicitly
