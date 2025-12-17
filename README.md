# Conchis

A clean, fast, keyboard-driven clipboard manager for macOS.

**Targets macOS 10.11+ (El Capitan)** - works on older Intel Macs.

## What is Conchis?

Conchis (from Greek *konche*, shell) is a fork of [Flycut](https://github.com/TermiT/Flycut) with:

- **Massive storage**: Up to 9,999 clipboard entries (default 500)
- **CI/CD builds**: Automated unsigned builds via GitHub Actions
- **10.11 compatibility**: Works on El Capitan and newer
- **Active development**: Building toward Quicksilver-style functionality

The conchoidal icon represents the smooth, curved fracture patterns found in shells and obsidian - a nod to both the name and the app's goal of smooth, frictionless clipboard management.

## Download

Get the latest build from [GitHub Actions](https://github.com/uprootiny/Flycut/actions) - download the `Conchis-zip` artifact.

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

## Roadmap

Building toward Quicksilver-style functionality, step by step:

- [ ] Quicksilver-style floating popup UI
- [ ] Comma trick for chaining actions
- [ ] Unlimited persistent storage (save all pastes forever)
- [ ] Clean hotkey configuration UI
- [ ] Apple HIG-compliant preferences
- [ ] Automatic grouping by app/time
- [ ] Enhanced filtering and navigation
- [ ] Comprehensive test coverage

## Building

```bash
git clone https://github.com/uprootiny/Flycut.git
cd Flycut
xcodebuild -project Flycut.xcodeproj -scheme Flycut -configuration Release build
```

Or push to trigger GitHub Actions.

## Philosophy

> "Write programs that do one thing and do it well." — Unix Philosophy

Conchis aims to be:
- **Minimal**: No bloat
- **Fast**: Instant response
- **Reliable**: Never lose a paste
- **Compatible**: Runs on older hardware

## License

MIT License - see original [Flycut](https://github.com/TermiT/Flycut).

## Credits

- Original [Flycut](https://github.com/TermiT/Flycut) by TermiT
- [Jumpcut](http://jumpcut.sourceforge.net/) (predecessor)
- This fork maintained by [@uprootiny](https://github.com/uprootiny)
