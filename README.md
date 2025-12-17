# Flycut (uprootiny fork)

A clean, fast, keyboard-driven clipboard manager for macOS.

**This fork targets macOS 10.11+ (El Capitan)** while adding modern improvements.

## What's Different

This fork of [TermiT/Flycut](https://github.com/TermiT/Flycut) includes:

- **Increased storage**: Up to 9,999 clipboard entries (default 500)
- **CI/CD builds**: Automated unsigned builds via GitHub Actions
- **10.11 compatibility**: Works on older Intel Macs
- **Active development**: Quicksilver-style UI improvements planned

## Download

Get the latest build from [GitHub Actions](https://github.com/uprootiny/Flycut/actions) - download the `Flycut-zip` artifact.

Since the app is unsigned, on first launch:
1. Right-click the app → Open
2. Click "Open" in the dialog

## Features

- **Keyboard-driven**: Cmd+Shift+V to access clipboard history
- **Fast**: Polls clipboard every second, instant access
- **Persistent**: Saves clipboard history to disk
- **Favorites**: Pin frequently used clips
- **Search**: Filter clips by content
- **Minimal**: Does one thing well

## Planned Improvements

- [ ] Quicksilver-style popup UI
- [ ] Unlimited persistent storage (save all pastes forever)
- [ ] Better hotkey configuration
- [ ] Apple HIG-compliant preferences
- [ ] Automatic grouping
- [ ] Enhanced filtering and navigation

## Building

```bash
# Clone
git clone https://github.com/uprootiny/Flycut.git
cd Flycut

# Build (requires Xcode)
xcodebuild -project Flycut.xcodeproj -scheme Flycut -configuration Release build
```

Or let GitHub Actions build it - push to trigger a build.

## Philosophy

> "Write programs that do one thing and do it well." — Unix Philosophy

This fork aims to be:
- **Minimal**: No bloat, no unnecessary features
- **Fast**: Instant response, low resource usage
- **Reliable**: Never lose a paste
- **Compatible**: Works on older hardware

## License

MIT License - see original [Flycut](https://github.com/TermiT/Flycut) for details.

## Credits

- Original [Flycut](https://github.com/TermiT/Flycut) by TermiT
- [Jumpcut](http://jumpcut.sourceforge.net/) (predecessor)
- This fork maintained by [@uprootiny](https://github.com/uprootiny)
