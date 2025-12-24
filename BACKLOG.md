# Fluxus Project Backlog

## Urgent / Unaligned Implementation
- [ ] **Gimbal Physical Mapping**: Move logic from `BezelWindow.m` into a standalone interaction module that handles hardware sensor input.
- [ ] **LLM Integration**: Wire the physical drift/velocity parameters to actual prompt engineering logic in `AppController.m`.
- [ ] **Search/Filter Hydration**: Implementing the `NSTextField` delegate to filter clips in real-time within the HUD.

## Tests & Robustness
- [ ] **UI State Tests**: Write XCTest for `BezelWindow` showing/hiding animations (checking final frame/alpha).
- [ ] **Coordinate Normalization Tests**: Ensure X/Y/Z mapping from gimbal to semantic space is consistent across screen resolutions.
- [ ] **Memory Leaks**: Audit Objective-C blocks and delegates.

## UI Design
- [ ] **Bezier Path Smoothing**: Implement `RoundRecBezierPath` for non-standard corner radii (Quicksilver style).
- [ ] **Adaptive Blur**: Switch `NSVisualEffectMaterial` based on system dark/light mode presence.
- [ ] **Haptic Feedback**: Implement Taptic Engine triggers for "detents" on the convex surface etched pathways.
